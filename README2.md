.\hyperv-kuspray.ps1 all minimal 
.\hyperv-kuspray.ps1 restore

# see poshgit module

 # mount and set temp for downloads 
 TODO : 
 
 docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray -ansible-playbook --become -i /opt/hyperv-kubespray/inventory/minimal.yaml /kubespray/cluster.yml
 
 # All

 # Mitigation : 
 (yum install -y sshpass) || (apt-get install -y sshpass)  on master Centos 8 for download roles 
 systemctl disable firewalld
[WARNING Firewalld]: firewalld is active, please ensure ports [6443 10250] are open or your cluster may not function correctly\n\t[WARNING Port-6443]: 


vagrant destroy -f; vagrant up; sleep 120; 
docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook --become -i /opt/hyperv-kubespray/inventory/minimal.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml; docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt && ansible-playbook --become -i /opt/hyperv-kubespray/inventory/minimal.yaml /opt/hyperv-kubespray/kubespray/cluster.yml" 
#RODO : create commands as aliases 


TASK [download : prep_kubeadm_images | Copy kubeadm binary from download dir to system path] 
**********************************************************************************Thursday 21 May 2020  12:57:39 +0000 (0:00:00.738)       0:04:12.966 **********
fatal: [k8s-node-1.mshome.net -> k8s-node-1.mshome.net]: FAILED! => {"changed": false, "cmd": "sshpass", "msg": "[Errno 2] No such file or directory: b'sshpass': b'sshpass'",
"rc": 2}
= >

/var/kubespray

# TODO : script with BOXS rolling and stat gathering




date; vagrant destroy -f; vagrant up;  echo "Vagrant up, sleep a while..."; sleep 30; date ; docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook --become -i /opt/hyperv-kubespray/inventory/minimal.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml; date; docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt && ansible-playbook --become -i /opt/hyperv-kubespray/inventory/minimal.yaml /opt/hyperv-kubespray/kubespray/cluster.yml"