#!/bin/bash
set -xe 
if [ -f ../helper_scripts/default.env ];
then 
  source ../helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

cd $KCLI_SAMPLES_DIR


ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
PULL_SECRET=$(yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
VM_NAME=openshift-jumpbox-$(echo $RANDOM | md5sum | head -c 5; echo;)
IMAGE_NAME=Fedora-Cloud-Base-37-1.7.x86_64.qcow2
DISK_SIZE=50
sudo rm -rf kcli-profiles.yml
if [ -f ~/.kcli/profiles.yml ]; then
  sudo cp  ~/.kcli/profiles.yml kcli-profiles.yml
else 
    sudo mkdir -p ~/.kcli
    sudo mkdir -p /root/.kcli
fi
if [ -d $HOME/.generated/vmfiles ]; then
  echo "generated directory already exists"
else
  sudo mkdir -p  $HOME/.generated/vmfiles
  sudo mkdir -p  /root/.generated/vmfiles
fi

cat >/tmp/vm_vars.yaml<<EOF
image: ${IMAGE_NAME}
user: fedora
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 8192
net_name: ${NET_NAME} 
reservedns: 1.1.1.1
offline_token: ${OFFLINE_TOKEN}
EOF

sudo python3 profile_generator/profile_generator.py update_yaml openshift-jumpbox openshift-jumpbox/template.yaml  --vars-file /tmp/vm_vars.yaml
sudo echo ${PULL_SECRET} | sudo tee pull-secret.json
cat  kcli-profiles.yml
ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp pull-secret.json  ~/.generated/vmfiles
sudo cp pull-secret.json /root/.generated/vmfiles
sudo cp $(pwd)/openshift-jumpbox/gitops.sh ~/.generated/vmfiles
sudo cp $(pwd)/openshift-jumpbox/gitops.sh /root/.generated/vmfiles
sudo rm pull-secret.json
#echo "Creating VM ${VM_NAME}"
#sudo kcli create vm -p openshift-jumpbox ${VM_NAME} --wait