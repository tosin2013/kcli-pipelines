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

# HARBOR_VERSION CA_URL FINGERPRINT env not found exit 
if [ -z "${HARBOR_VERSION}" ] || [ -z "${CA_URL}" ] || [ -z "${FINGERPRINT}" ] || [ -z ${STEP_CA_PASSWORD} ]; then
    echo "HARBOR_VERSION CA_URL FINGERPRINT STEP_CA_PASSWORD env variables must be set"
    exit 1
fi


cd $KCLI_SAMPLES_DIR
IMAGE_NAME=ubuntu

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
VM_NAME=harbor
# FreeIPA DNS ADDRESS
export vm_name="freeipa"
export ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}' | head -1)
DISK_SIZE=300
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
if [ -f /home/${KCLI_USER}/.kcli/profiles.yml ]; then
  sudo cp  /home/${KCLI_USER}/.kcli/profiles.yml kcli-profiles.yml
else 
    sudo mkdir -p /home/${KCLI_USER}/.kcli
    sudo mkdir -p /root/.kcli
fi

cat >/tmp/vm_vars.yaml<<EOF
image: ${IMAGE_NAME}
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 8192
net_name: ${NET_NAME} 
reservedns: ${ip_address}
domain: ${DOMAIN}
harbor_version: ${HARBOR_VERSION}
ca_url: ${CA_URL}
fingerprint: ${FINGERPRINT}
initial_password: ${STEP_CA_PASSWORD}
EOF
sudo python3 profile_generator/profile_generator.py update_yaml harbor harbor/template.yaml  --vars-file /tmp/vm_vars.yaml
#cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
