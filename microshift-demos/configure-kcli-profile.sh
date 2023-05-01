#!/bin/bash
set -xe 
if [ -f ../helper_scripts/default.env ];
then 
  source ../helper_scripts/default.env
elif [ -f helper_scripts/default.env  ];
then 
  source helper_scripts/default.env 
else
  echo "default.env file does not exist"
  exit 1
fi

cd $KCLI_SAMPLES_DIR

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
PULL_SECRET=$(yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
VM_NAME=microshift-demos-vm
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
IMAGE_NAME=rhel9
DISK_SIZE=200
MEMORTY=32768
CPU_NUM=8
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
sudo rm -rf kcli-profiles.yml
if [ -f /home/${KCLI_USER}/.kcli/profiles.yml ]; then
  sudo cp  /home/${KCLI_USER}/.kcli/profiles.yml kcli-profiles.yml
else 
    sudo mkdir -p /home/${KCLI_USER}/.kcli
    sudo mkdir -p /root/.kcli
fi
if [ -d /home/${KCLI_USER}/vmfiles ]; then
  echo "generated directory already exists"
else
  sudo mkdir -p  /home/${KCLI_USER}/.generated/vmfiles
  sudo mkdir -p  /root/.generated/vmfiles
fi


cat >/tmp/vm_vars.yaml<<EOF
image: ${IMAGE_NAME}
user: cloud-user
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: ${CPU_NUM}
memory: ${MEMORTY}
net_name: ${NET_NAME} 
reservedns: ${DNS_FORWARDER}
offline_token: ${OFFLINE_TOKEN}
rhnorg: ${RHSM_ORG}
rhnactivationkey: ${RHSM_ACTIVATION_KEY} 
EOF

sudo python3 profile_generator/profile_generator.py update_yaml microshift-demos microshift-demos/template.yaml  --vars-file /tmp/vm_vars.yaml
sudo echo ${PULL_SECRET} | sudo tee pull-secret.json
cat pull-secret.json
cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
sudo cp  pull-secret.json  /home/${KCLI_USER}/.generated/vmfiles
sudo cp pull-secret.json /root/.generated/vmfiles
sudo rm pull-secret.json
sudo cp $(pwd)/device-edge-workshops/setup-demo-infra.sh /home/${KCLI_USER}/.generated/vmfiles
sudo cp $(pwd)/device-edge-workshops/setup-demo-infra.sh /root/.generated/vmfiles
#echo "Creating VM ${VM_NAME}"
#echo "Creating VM ${VM_NAME}"
#sudo kcli create vm -p microshift-demos ${VM_NAME} --wait
#echo "VM ${VM_NAME} created"
#echo "sudo kcli ssh ${VM_NAME}"
#echo "sudo su - "
#echo "ssh-keygen -t rsa -b 4096 -f /home/${KCLI_USER}/.ssh/cluster-key -N ''"
#echo "ssh-copy-id -i /home/${KCLI_USER}/.ssh/cluster-key admin@192.168.1.123"
