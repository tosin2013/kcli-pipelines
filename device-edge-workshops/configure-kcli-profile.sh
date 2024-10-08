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

if [  -f /root/.vault_password ]; then
  echo "vault password file already exists"
else
  echo "vault password file does not exist"
  #exit 1
fi
source helper_scripts/helper_functions.sh

cd $KCLI_SAMPLES_DIR


/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHEL_USERNAME=$(yq eval '.rhsm_username' "${ANSIBLE_VAULT_FILE}")
RHEL_PASSWORD=$(yq eval '.rhsm_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
PULL_SECRET=$(yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
VM_NAME=device-edge-deployer
IMAGE_NAME=rhel9
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
if [ ! -z ${BASE_ZONE} ];
then
  DOMAIN=${GUID}.${BASE_ZONE}
  ${USE_SUDO} yq e -i '.domain = "'${BASE_ZONE}'"' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/all.yml
else
  DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
fi

if [ -z ${SLACK_APP_TOKEN} ];
then
  echo "Slack APP token not set"
  export SLACK_APP_TOKEN="temp"
fi

if [ -z ${APP1_REGISTRY} ];
then
  echo "quay.io registry one not set"
  export APP1_REGISTRY="temp"
fi

if [ -z ${APP2_REGISTRY} ];
then
  echo "quay.io registry one not set"
  export APP2_REGISTRY="temp"
fi

if [ -z ${BASE64_MANIFEST} ];
then
  echo "Base64 manifest not set"
  export BASE64_MANIFEST="temp"
fi

DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
DISK_SIZE=120
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")

#  https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software
PROVIDED_SHA_VALUE=7c4509b3436c7423a60a65815493b3d66162acd09dbca131a9b5edad9e319a40 #$(yq eval '.provided_sha_value' "${ANSIBLE_ALL_VARIABLES}")

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


if ! kcli list networks | grep -q internal-net; then
    kcli create network -c 192.168.40.0/24 internal-net -P dhcp=false -P dns=false
fi

if ! kcli list networks | grep -q external-net; then
    kcli create network -c 192.168.41.0/24 external-net
fi


echo "${PULL_SECRET}" > pull-secret.json
cat >/tmp/vm_vars.yaml<<EOF
image: ${IMAGE_NAME}
user: cloud-user
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 8
memory: 32736
internal_net_name: internal-net
external_net_name: external-net
reservedns: 1.1.1.1
domainname: ${DOMAIN}
offline_token: ${OFFLINE_TOKEN}
rhnorg: ${RHSM_ORG}
rhel_username: ${RHEL_USERNAME}
rhel_password: ${RHEL_PASSWORD}
rhnactivationkey: ${RHSM_ACTIVATION_KEY} 
provided_sha_value: ${PROVIDED_SHA_VALUE}
EOF

determine_command_yaml
sudo python3 profile_generator/profile_generator.py $COMMAND device-edge-workshops device-edge-workshops/template.yaml  --vars-file /tmp/vm_vars.yaml
#cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
sudo cp pull-secret.json  /home/${KCLI_USER}/.generated/vmfiles
sudo cp pull-secret.json /root/.generated/vmfiles
sudo rm pull-secret.json
#echo "Creating VM ${VM_NAME}"
#sudo kcli create vm -p rhel8 ${VM_NAME} --wait
