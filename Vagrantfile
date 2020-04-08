# -*- mode: ruby -*-
# vim: ft=ruby

# Thanks to : https://github.com/debops/examples/blob/master/vagrant-multi-machine/Vagrantfile ! 


# This script is used to create multiple VMs with vagrant on Win 10 laptop

# I use ubuntu vm for dev
# But must launch vragrant into power shell :) 


# Network configuration
DOMAIN            = ".k8s.local"
# Box
UBUNTU_BOX = "generic/ubuntu1804"
CENTOS7_BOX = "centos/7"
DEBIAN10_BOX = "generic/debian10"


# I use create static MAC adresses because hyperv dhcp has a *very* little range by default and dont wanna clean on every reset
# HOSTS = {
#   "name" => [mac, cpus, mem, box, secondMacForControlPlane],
# }

# a lot of memory :) 
# this will take ... some time 
# let's check memory 
# Everything is ok so far 
# 51 plus a last node with 8 => okay I have enough mem 
# \0/ 

# next step => launch kubespray 
# stay tuned ! 

HOSTS = {
   "k8s-etcd-1" => ["020000000001", 2, 4096, CENTOS7_BOX, "020000000011", "020000000021"],
   "k8s-etcd-2" => ["020000000002", 2, 4096, UBUNTU_BOX, "020000000012", "020000000022"],
   "k8s-master-node-etcd-1" => ["020000000003", 4, 8192, CENTOS7_BOX, "020000000013", "020000000023"],
   "k8s-master-1" => ["020000000004", 2, 4096, CENTOS7_BOX, "020000000014", "020000000024"],
   "k8s-master-2" => ["020000000005", 2, 4096, UBUNTU_BOX, "020000000015", "020000000025"],
   "k8s-node-1" => [ "020000000006", 4, 8192, CENTOS7_BOX, "020000000016", "020000000026"],
   "k8s-node-2" => [ "020000000007", 4, 8192, UBUNTU_BOX, "020000000017", "020000000027"],
}

ANSIBLE_INVENTORY_DIR = 'ansible/inventory'

# ---- Vagrant configuration ----

Vagrant.configure(2) do |config|
  HOSTS.each do | (name, cfg) |
    mac, cpus, ram, box, secondMac, thirdMac = cfg

    config.vm.define name do |machine|
      machine.vm.box   = box
	  machine.vm.hostname = name
      machine.vm.provision "file", source: "id_rsa.pub", destination: "/home/vagrant/.ssh/me.pub"

      machine.vm.provision "shell", privileged: true, inline: <<-SHELL
cat /home/vagrant/.ssh/me.pub >> /home/vagrant/.ssh/authorized_keys
(apt-get -y update && apt-get -y upgrade && apt -y install python) || (yum -y clean all && yum makecache && yum -y update && yum -y install python)
echo "[keyfile]" > /etc/NetworkManager/conf.d/planes.conf || true
echo "unmanaged-devices=interface-name:eth1;interface-name:eth2" > /etc/NetworkManager/conf.d/planes.conf || true
swapoff -a
SHELL

      # add second itf with staic ip for robust k8s
      machine.trigger.after :up do |trigger|
        trigger.run = {privileged: "true", powershell_elevated_interactive: "true", path: "./addItfIfNotExists.ps1", args: ["-vmName", name, "-macAddrCtrlPlane", secondMac, "-macAddrDataPlane", thirdMac]} 
      end
      
      machine.vm.provider "hyperv" do |hv|
        hv.memory = ram
        hv.maxmemory = ram
        hv.cpus = cpus
		hv.mac = mac
		hv.vmname = name
      end

    end # config.vm.define
  end # HOSTS-each
end

#Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {vagrant push snapshot $_.Name}