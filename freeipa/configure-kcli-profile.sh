#!/bin/bash
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
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

if [ $TARGET_SERVER == "equinix" ];
then 
  source ~/.profile 
  ANSIBLE_GALAXY=/root/.local/bin/ansible-galaxy
else 
  ANSIBLE_GALAXY=/usr/local/bin/ansible-galaxy
fi

cd $KCLI_SAMPLES_DIR


/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
FREEIPA_PASSWORD=$(yq eval '.freeipa_server_admin_password' "${ANSIBLE_VAULT_FILE}")
VM_NAME=freeipa-workshop-deployer-$(echo $RANDOM | md5sum | head -c 5; echo;)
IMAGE_NAME=rhel8
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


git clone https://github.com/tosin2013/freeipa-workshop-deployer.git
cd freeipa-workshop-deployer
cp example.vars.sh vars.sh
sed -i 's/INFRA_PROVIDER=.*/INFRA_PROVIDER="kcli"/' vars.sh
sed -i 's/INVENTORY=.*/INVENTORY='${INVENTORY}'/' vars.sh
sed -i 's/KCLI_NETWORK=.*/KCLI_NETWORK="'${NET_NAME}'"/' vars.sh