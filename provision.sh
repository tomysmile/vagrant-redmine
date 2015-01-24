#!/usr/bin/env bash

# Script to create a vagrant image with redmine ready to use.
set -x

# Uncomment the selected web server.
#USE_NGINX=1
USE_APACHE2=1

# Uncomment the selected database.
USE_MYSQL=1
#USE_PGSQL=1
#
# Uncomment if extra images libraries for redmine will be installed.
USE_IMAGEMAGICK=1

# Set password. Change at your preference.
DB_PASSWORD='1234567890'
REDMINE_PASSWORD='1234567890'

set +x

# Set non-interactive instaler mode, update repos.
export DEBIAN_FRONTEND=noninteractive

if ! test -f .updated_apt_get; then
  echo 'Updating and installing ubuntu packages...'
  # Do actual update packages
  apt-get -y update
  touch .updated_apt_get
fi

dpkg -s git &>/dev/null || {
  echo 'Installing supporting tools...'
  apt-get -y install git curl build-essential
}

# Install and setup database.
if [[ -n ${USE_MYSQL} ]]; then
  # Setup and install mysql-server
  dpkg -s mysql-server &>/dev/null || {
    echo "redmine redmine/instances/default/database-type select mysql" | debconf-set-selections
    echo "redmine redmine/instances/default/mysql/method select unix socket" | debconf-set-selections
    echo "redmine redmine/instances/default/mysql/app-pass password ${DB_PASSWORD}" | debconf-set-selections
    echo "redmine redmine/instances/default/mysql/admin-pass password ${DB_PASSWORD}" | debconf-set-selections
    echo "mysql-server mysql-server/root_password password ${DB_PASSWORD}" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password ${DB_PASSWORD}" | debconf-set-selections
    apt-get install -q -y mysql-server mysql-client
    apt-get install -q -y redmine-mysql
  }

elif [[ -n ${USE_PGSQL} ]]; then
  # Setup and install pgsql-server
  dpkg -s postgresql &>/dev/null || {
    echo "redmine redmine/instances/default/database-type select pgsql" | debconf-set-selections
    echo "redmine redmine/instances/default/pgsql/method select unix socket" | debconf-set-selections
    echo "redmine redmine/instances/default/pgsql/authmethod-admin select ident" | debconf-set-selections
    echo "redmine redmine/instances/default/pgsql/authmethod-user select ident" | debconf-set-selections
    echo "redmine redmine/instances/default/pgsql/app-pass password" | debconf-set-selections
    echo "redmine redmine/instances/default/pgsql/admin-pass password" | debconf-set-selections
    echo "dbconfig-common dbconfig-common/pgsql/authmethod-admin select ident" | debconf-set-selections
    echo "dbconfig-common dbconfig-common/pgsql/authmethod-user select ident" | debconf-set-selections
    apt-get install -q -y postgresql postgresql-contrib
    apt-get install -q -y redmine-pgsql
  }
fi

# Install redmine.
dpkg -s redmine &>/dev/null || {
  echo "redmine redmine/instances/default/app-password password ${REDMINE_PASSWORD}" | debconf-set-selections
  echo "redmine redmine/instances/default/app-password-confirm password ${REDMINE_PASSWORD}" | debconf-set-selections
  echo "redmine redmine/instances/default/dbconfig-install boolean true" | debconf-set-selections
  apt-get install -q -y redmine

  # Extra required package for ubuntu 14.04 to make redmine work.
  gem install bundler

  # Extras
  if [[ -n ${USE_IMAGEMAGICK} ]]; then
    apt-get install -q -y imagemagick
    apt-get install -q -y ruby-rmagick
  fi
}

# Change permissions for redmine directory.
chown www-data:www-data /usr/share/redmine

#############################################
# Install web servers.
#############################################
# Install apache2
dpkg -s apache2 &>/dev/null || {
  apt-get install -q -y apache2 libapache2-mod-passenger

  # Link redmine into apache2.
  ln -s /usr/share/redmine/public /var/www/redmine
}

if ! test -f .apache2_configured; then

  if test -f /etc/apache2/sites-available/default; then
    touch /etc/apache2/sites-available/000-default.conf

    rm -f /etc/apache2/sites-enabled/000-default
    ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/000-default
  fi

  # Override apache settings.
  dd of=/etc/apache2/sites-available/000-default.conf <<EOF
  <VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/redmine
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    <Directory /var/www/redmine>
      RailsBaseURI /
      PassengerResolveSymlinksInDocumentRoot on
    </Directory>
  </VirtualHost>
EOF

  # Configure passenger
  dd of=/etc/apache2/mods-available/passenger.conf <<EOF
  <IfModule mod_passenger.c>
    PassengerDefaultUser www-data
    PassengerRoot /usr
    PassengerRuby /usr/bin/ruby
  </IfModule>
EOF


  touch .apache2_configured
fi

# Restart apache2
service apache2 restart

dpkg -s subversion &>/dev/null || {
  echo 'Installing subversion...'
  apt-get -y install subversion cvs mercurial
}

dpkg -s postfix &>/dev/null || {
  echo 'Installing postfix mail...'
  apt-get -y install postfix
}

  cat <<EOF
  ################################################
  # Now you should be able to see redmine webpage
  # http://localhost:8888
  ################################################
EOF

