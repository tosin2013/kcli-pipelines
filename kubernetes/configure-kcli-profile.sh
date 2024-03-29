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

cd $KCLI_SAMPLES_DIR


/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
VM_NAME=rhel9-$(echo $RANDOM | md5sum | head -c 5; echo;)
IMAGE_NAME=rhel9
DNS_FORWARDER=$(sudo kcli info vm freeipa | grep ip: | awk '{print $2}' | head -1)
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
DISK_SIZE=50
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
sudo rm -rf kcli-profiles.yml
if [ -f /home/${KCLI_USER}/.kcli/profiles.yml ]; then
  sudo cp  /home/${KCLI_USER}/.kcli/profiles.yml kcli-profiles.yml
else 
    sudo mkdir -p /home/${KCLI_USER}/.kcli
    sudo mkdir -p /root/.kcli
fi
if [ -d /home/${KCLI_USER}/.generated/vmfiles ]; then
  echo "generated directory already exists"
else
  sudo mkdir -p  /home/${KCLI_USER}/.generated/vmfiles
  sudo mkdir -p  /root/.generated/vmfiles
fi

sed -i "s/CHANGEUSER/${KCLI_USER}/g" kubernetes/kubernetes.yml
sed -i "s/CHANGEPASSWORD/${PASSWORD}/g" kubernetes/kubernetes.yml
sed -i "s/qubinet/${NET_NAME}/g" kubernetes/kubernetes.yml
sed -i "s/DNS_ENDPOINT/${DNS_FORWARDER}/g" kubernetes/kubernetes.yml
sed -i "s/DOMAIN_NAME/${DOMAIN}/g" kubernetes/kubernetes.yml


#cat kubernetes/kubernetes.yml