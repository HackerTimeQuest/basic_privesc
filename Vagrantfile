# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do | config |
  config.vm.box = "bento/ubuntu-20.04"
  config.vm.hostname = "wackywarehouse"

  # Host-only network for isolation
  config.vm.network "private_network", ip: "192.168.49.10"

  # Forward SSH for convenience; also reachable on 192.168.49.10:22
  config.vm.network "forwarded_port", guest: 22, host: 2222, auto_correct: true

  # Disable Vagrant's insecure key — we use password auth
  config.vm.synced_folder ".", "/vagrant", type: "rsync"

  # Synced folders (rsync mode for read-only repo content)
  config.vm.synced_folder ".", "/vagrant", type: "rsync"

  # Provision with cloud-init using the repo user-data file.
  config.vm.provision "file" do |f|
    f.source      = "infrastructure/cloud-init/basic-privesc.yaml"
    f.destination = "/tmp/basic-privesc.yaml"
  end

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    set -euo pipefail
    apt-get update -y
    apt-get install -y --no-install-recommends cloud-init
    mkdir -p /var/lib/cloud/seed/nocloud
    cp /tmp/basic-privesc.yaml /var/lib/cloud/seed/nocloud/user-data
    chmod 644 /var/lib/cloud/seed/nocloud/user-data
    cloud-init clean
    cloud-init init
    cloud-init modules --mode=config
    cloud-init modules --mode=final
  SHELL

  # SSH timeouts that suit a dev VM
  config.ssh.insert_key = false
  config.ssh.private_key_path = "~/.vagrant.d/insecure_private_key"
  config.ssh.username = "appuser"
  config.ssh.password = "wareh0use!"
  config.ssh.pty = true
  config.ssh.timeout = 120

  # RAM / CPU (minimal; 1 GB is plenty for a privesc box)
  if Vagrant::Util::Platform.windows?
    config.vm.provider "virtualbox" do | vb |
      vb.name    = "hacker-time-privesc"
      vb.memory  = 1024
      vb.cpus    = 1
    end
  else
    config.vm.provider "virtualbox" do | vb |
      vb.name    = "hacker-time-privesc"
      vb.memory  = 1024
      vb.cpus    = 1
      vb.linked_clone = true
    end
  end

  # Parallels / VMware stubs (uncomment as needed)
  #config.vm.provider "parallels" do | pb | pb.memory = 1024; end
  #config.vm.provider "vmware_fusion" do | pv | pv.vmx["memsize"] = 1024; end
end
