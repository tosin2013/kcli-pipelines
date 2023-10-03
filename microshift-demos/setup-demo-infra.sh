#!/bin/bash 
# https://github.com/redhat-et/microshift-demos

if [ -d $HOME/microshift-demos ]; then
  echo "microshift-demos directory already exists"
  cd microshift-demos
else
  cd $HOME
  git clone https://github.com/redhat-et/microshift-demos.git
  cd microshift-demos
fi 

if [ -f $HOME/.pull-secret.json ]; then
  echo "pull-secret.json already exists"
else
  echo "pull-secret.json does not exist"
  exit 1
fi

function configure_os(){
  ./scripts/configure-builder
  export  MICROSHIFT_DEV_PREVIEW=true 
  ./scripts/mirror-repos
}


cat >playbooks.yml<<EOF
- hosts: client
  roles:
    - rhel-edge-kvm-role
EOF

IP_ADDRESS=$(hostname -I)


sudo ansible-galaxy install git+https://github.com/tosin2013/rhel-edge-kvm-role.git --force

sed 's/rhel-edge-kvm.iso/hello-microshift-demo-installer.x86_64.iso/g' edge_vars.yml > edge_vars_use.yml
sudo ansible-playbook  -i hosts playbooks.yml -t create_kvm_vm  --extra-vars "@edge_vars_use.yml"  --private-key ~/.ssh/cluster-key -K

sudo ansible-playbook  -i hosts playbooks.yml -t destroy_kvm_vm --extra-vars "@edge_vars_use.yml" -K


# Requirements for target machine
#ansible-galaxy collection install community.libvirt
#ansible-galaxy collection install ansible.posix
#ansible-galaxy collection install community.general