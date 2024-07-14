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
source helper_scripts/helper_functions.sh
cd $KCLI_SAMPLES_DIR
IMAGE_NAME=ubuntu2204

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
VM_NAME=ollama-api-$(echo $RANDOM | md5sum | head -c 5; echo;)
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
DISK_SIZE=180
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
if [ ! -z "${HUGGINGFACE_API_KEY}" ]; then
    echo "Huggingface API key is set"
else 
    echo "Huggingface API key is not set"
    exit 1
fi
# Thinkinig about adding to vault.yml file
#HUGGINGFACE_API_KEY=$(yq eval '.huggingface_api_key' "${ANSIBLE_ALL_VARIABLES}")
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
numcpus: 8
memory: 32768
net_name: ${NET_NAME} 
reservedns: ${DNS_FORWARDER}
domain: ${DOMAIN}
huggingface_api_key: ${HUGGINGFACE_API_KEY}
EOF

determine_command_yaml
sudo python3 profile_generator/profile_generator.py $COMMAND ollama-api ollama-api/template.yaml  --vars-file /tmp/vm_vars.yaml

#cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml

