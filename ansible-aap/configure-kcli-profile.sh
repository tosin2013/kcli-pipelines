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

cd $KCLI_SAMPLES_DIR

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
RHEL_USERNAME=$(yq eval '.rhsm_username' "${ANSIBLE_VAULT_FILE}")
RHEL_PASSWORD=$(yq eval '.rhsm_password' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
PROVIDED_SHA_VALUE=7456b98f2f50e0e1d4c93fb4e375fe8a9174f397a5b1c0950915224f7f020ec4 #$(yq eval '.provided_sha_value' "${ANSIBLE_ALL_VARIABLES}")
#sudo rm -rf kcli-profiles.yml
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

cat >/tmp/vm_vars.yaml<<EOF
image: rhel9
user: $USER
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 16384
net_name: ${NET_NAME} 
rhnorg: ${RHSM_ORG}
rhnactivationkey: ${RHSM_ACTIVATION_KEY} 
reservedns: ${DNS_FORWARDER}
offline_token: ${OFFLINE_TOKEN}
rhel_username: ${RHEL_USERNAME}
rhel_password: ${RHEL_PASSWORD}
provided_sha_value: ${PROVIDED_SHA_VALUE}
EOF

sudo python3 profile_generator/profile_generator.py update_yaml ansible-aap ansible-aap/ansible-aap.yml  --vars-file /tmp/vm_vars.yaml
cat  kcli-profiles.yml