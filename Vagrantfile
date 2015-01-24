# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/precise64"
  config.vm.hostname = "redmine-srvr"

  config.vm.network "forwarded_port", host: 8888, guest: 80, id: "redmine", auto_correct: true

  config.vm.provision "shell", path: "provision.sh"

  config.vm.provider :virtualbox do |vb|
    vb.name = "redmine-srvr"
    vb.customize ["modifyvm", :id, "--memory", "1024"]
  end

end
