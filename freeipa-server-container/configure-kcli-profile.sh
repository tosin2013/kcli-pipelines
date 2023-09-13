#!/bin/bash
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe
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

if [ $TARGET_SERVER == "equinix" ];
then 
  source ~/.profile 
  ANSIBLE_GALAXY=/root/.local/bin/ansible-galaxy
else 
  ANSIBLE_GALAXY=ansible-galaxy
fi

cd $KCLI_SAMPLES_DIR


/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
FREEIPA_PASSWORD=$(yq eval '.freeipa_server_admin_password' "${ANSIBLE_VAULT_FILE}")
IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
VM_NAME=freeipa-server-container-$(echo $RANDOM | md5sum | head -c 5; echo;)
IMAGE_NAME=Fedora-Cloud-Base-38-1.6.x86_64.qcow2
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
DISK_SIZE=50
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
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
user: fedora
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 2
memory: 4092
net_name: ${NET_NAME} 
reservedns: ${DNS_FORWARDER}
domainname: ${DOMAIN}
freeipa_server_admin_password: ${FREEIPA_PASSWORD}
EOF
sudo kcli download image ${IMAGE_NAME} -u  ${IMAGE_URL}
sudo python3 profile_generator/profile_generator.py update-yaml freeipa-server-container freeipa-server-container/template.yaml  --vars-file /tmp/vm_vars.yaml
#cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml

#echo "Creating VM ${VM_NAME}"
#sudo kcli create vm -p freeipa-server-container ${VM_NAME} --wait

if [ ! -d .ansible/collections/ansible_collections/community ];
then 
  ${ANSIBLE_GALAXY} collection install community.general
fi 