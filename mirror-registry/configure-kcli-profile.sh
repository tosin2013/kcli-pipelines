#!/bin/bash
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
if [ -f ../helper_scripts/default.env ]; then
  source ../helper_scripts/default.env
elif [ -f helper_scripts/default.env ]; then
  source helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi
source helper_scripts/helper_functions.sh
# QUAY_VERSION CA_URL FINGERPRINT env not found exit
if [ -z "${QUAY_VERSION}" ] || [ -z "${CA_URL}" ] || [ -z "${FINGERPRINT}" ] || [ -z ${STEP_CA_PASSWORD} ]; then
  echo "QUAY_VERSION CA_URL FINGERPRINT STEP_CA_PASSWORD env variables must be set"
  exit 1
fi
source helper_scripts/helper_functions.sh

cd $KCLI_SAMPLES_DIR

IMAGE_NAME=rhel8

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
PULL_SECRET=$(yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
VM_NAME=mirror-registry
DISK_SIZE=300
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

if [ -f /home/${KCLI_USER}/.kcli/profiles.yml ]; then
  sudo cp /home/${KCLI_USER}/.kcli/profiles.yml kcli-profiles.yml
else
  sudo mkdir -p /home/${KCLI_USER}/.kcli
  sudo mkdir -p /root/.kcli
fi

if [ -d /home/${KCLI_USER}/.generated/vmfiles ]; then
  echo "generated directory already exists"
else
  sudo mkdir -p /home/${KCLI_USER}/.generated/vmfiles
  sudo mkdir -p /root/.generated/vmfiles
fi

# FreeIPA DNS ADDRESS
export vm_name="freeipa"
export ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}' | head -1)

cat >/tmp/vm_vars.yaml<<EOF
image: ${IMAGE_NAME}
user: cloud-user
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE}
numcpus: 4
memory: 8192
net_name: ${NET_NAME}
reservedns: ${ip_address}
offline_token: ${OFFLINE_TOKEN}
domain: ${DOMAIN}
rhnorg: ${RHSM_ORG}
rhnactivationkey: ${RHSM_ACTIVATION_KEY}
initial_password: ${STEP_CA_PASSWORD}
quay_version: ${QUAY_VERSION}
ca_url: ${CA_URL}
fingerprint: ${FINGERPRINT}
EOF

determine_command_yaml
sudo python3 profile_generator/profile_generator.py $COMMAND mirror-registry mirror-registry/template.yaml --vars-file /tmp/vm_vars.yaml
sudo echo ${PULL_SECRET} | sudo tee pull-secret.json > /dev/null
##cat kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
sudo cp pull-secret.json /home/${KCLI_USER}/.generated/vmfiles
sudo cp pull-secret.json /root/.generated/vmfiles
sudo rm pull-secret.json
#echo "Creating VM ${VM_NAME}"
#sudo kcli create vm -p mirror-registry ${VM_NAME} --wait