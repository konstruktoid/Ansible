Vagrant.configure(2) do |config|
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.default_nic_type = "Am79C973"
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
  end

  config.vm.define "bastion01" do |bastion01|
    bastion01.vm.box = "ubuntu/focal64"
    bastion01.vm.network "public_network", ip: "192.168.0.45"
    bastion01.vm.network "private_network", ip:"10.2.3.44"
    bastion01.vm.hostname = "bastion01"
    bastion01.vm.boot_timeout = 600
    bastion01.vm.provision "shell",
      inline: "apt-get update && apt-get -y install python3-pexpect --no-install-recommends"
  end

  config.vm.define "loadbalancer01" do |loadbalancer|
    loadbalancer.vm.box = "ubuntu/focal64"
    loadbalancer.vm.network "private_network", ip: "10.2.3.43"
    loadbalancer.vm.hostname = "loadbalancer01"
    loadbalancer.vm.boot_timeout = 600
    loadbalancer.vm.provision "shell",
      inline: "apt-get update && apt-get -y install python3-pexpect --no-install-recommends"
  end

  (1..2).each do |i|
    config.vm.define "webserver0#{i}" do |webserver|
      webserver.vm.box = "ubuntu/focal64"
      webserver.vm.network "private_network", ip:"10.2.3.4#{i}"
      webserver.vm.hostname = "webserver0#{i}"
      webserver.vm.boot_timeout = 600
      webserver.vm.provision "shell",
        inline: "apt-get update && apt-get -y install python3-pexpect --no-install-recommends"
    end
  end
end
