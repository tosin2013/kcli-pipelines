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
GIT_REPO="https://github.com/tosin2013/rhel-fleet-management-configurator.git"
PATH_NAME="rhel-fleet-management-configurator"
cd $KCLI_SAMPLES_DIR

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
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

cat >/tmp/vm_vars.yaml<<EOF
image: rhel-baseos-9.1-x86_64-kvm.qcow2
user: $USER
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 8192
net_name: ${NET_NAME} 
rhnorg: ${RHSM_ORG}
rhnactivationkey: ${RHSM_ACTIVATION_KEY} 
reservedns: ${DNS_FORWARDER}
offline_token: ${OFFLINE_TOKEN}
git_repo: ${GIT_REPO}
path_name: ${PATH_NAME}
EOF

sudo python3 profile_generator/profile_generator.py update_yaml ansible-aap ansible-aap/ansible-aap.yml  --vars-file /tmp/vm_vars.yaml
sudo python3 profile_generator/profile_generator.py update_yaml ansible-hub ansible-aap/ansible-hub.yml --vars-file /tmp/vm_vars.yaml
sudo python3 profile_generator/profile_generator.py update_yaml postgres ansible-aap/postgres.yml --vars-file /tmp/vm_vars.yaml
sed -i 's/ansible-aap/ansible-hub/g' $(pwd)/ansible-aap/setup-aap.sh 
sudo cp $(pwd)/ansible-aap/setup-aap.sh  /home/${KCLI_USER}/.generated/vmfiles
sudo cp $(pwd)/ansible-aap/setup-aap.sh  /root/.generated/vmfiles
cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
#sudo cp kcli-profiles.yml ansible-aap/plan.yml
#sudo kcli create plan -f ansible-aap/plan.yml
#sleep 30s

#ANSIBLE_AAP=ansible-aap
#ANSIBLE_HUB=ansible-hub
#POSTGRES=postgres
#../helper_scripts/get-ips-by-mac.sh ${ANSIBLE_AAP} ${ANSIBLE_HUB} ${POSTGRES} setup-aap.sh
#sudo kcli scp setup-aap.sh ansible-aap:/tmp


#sudo kcli ssh setup-aap
#sudo su - 
#chmod +x /tmp/setup-aap.sh
#/tmp/setup-aap.sh