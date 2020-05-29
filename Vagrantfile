Vagrant.configure(2) do |config|
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.default_nic_type = "Am79C973"
  end

  (1..2).each do |i|
    config.vm.define "focal#{i}" do |focal|
      focal.vm.box = "ubuntu/focal64"
      focal.vm.network "private_network", ip:"10.2.3.4#{i}"
      focal.vm.hostname = "focal#{i}"
      focal.vm.boot_timeout = 600
      focal.vm.provision "shell",
        inline: "apt-get update && apt-get -y install python3-pexpect --no-install-recommends"
    end
  end

  config.vm.define "buster" do |buster|
    buster.vm.box = "bento/debian-10"
    buster.ssh.insert_key = true
    buster.vm.network "private_network", ip: "10.2.3.43"
    buster.vm.hostname = "buster"
    buster.vm.boot_timeout = 600
    buster.vm.provision "shell",
      inline: "apt-get update && apt-get -y install python3-pexpect --no-install-recommends"
  end

  config.vm.define "centos" do |centos|
    centos.vm.box = "bento/centos-8"
    centos.ssh.insert_key = true
    centos.vm.network "private_network", ip: "10.2.3.44"
    centos.vm.provider "virtualbox" do |c|
      c.default_nic_type = "82543GC"
    end
    centos.vm.hostname = "centos"
    centos.vm.boot_timeout = 600
    centos.vm.provision "shell",
      inline: "yum -y update && yum -y install python3"
  end

  config.vm.define "fedora" do |fedora|
    fedora.vm.box = "bento/fedora-31"
    fedora.ssh.insert_key = true
    fedora.vm.network "private_network", ip: "10.2.3.45"
    fedora.vm.hostname = "fedora"
    fedora.vm.boot_timeout = 600
  end
end
