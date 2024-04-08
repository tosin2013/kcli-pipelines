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

if [ ! -z ${CERTIFICATE_PATH} ];
then
  CERTIFICATE_PATH=${CERTIFICATE_PATH}
  echo "Certificate path is ${CERTIFICATE_PATH}" || exit $?
else
  echo "Certificate path is not set"
  touch /tmp/certificate.crt
  CERTIFICATE_PATH=/tmp/certificate.crt
fi

if [ ! -z ${KEY_PATH} ];
then
  KEY_PATH=${KEY_PATH}
  echo "Key path is ${KEY_PATH}" || exit $?
else
  touch /tmp/certificate.key
  KEY_PATH=/tmp/certificate.key
fi

cd $KCLI_SAMPLES_DIR
IMAGE_URL="https://opencolo.mm.fcix.net/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2"
IMAGE_NAME=Fedora-Cloud-Base-39-1.5.x86_64.qcow2
sudo kcli download image ${IMAGE_NAME} -u  ${IMAGE_URL}

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
PULL_SECRET=$(yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
VM_NAME=mirror-registry-$(echo $RANDOM | md5sum | head -c 5; echo;)
DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
DISK_SIZE=300
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
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
image: ${IMAGE_NAME}
user: fedora
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 8192
net_name: ${NET_NAME} 
reservedns: ${DNS_FORWARDER}
offline_token: ${OFFLINE_TOKEN}
domain: ${DOMAIN}
EOF

sudo python3 profile_generator/profile_generator.py update-yaml mirror-registry mirror-registry/template.yaml  --vars-file /tmp/vm_vars.yaml
sudo echo ${PULL_SECRET} | sudo tee pull-secret.json  > /dev/null
##cat  kcli-profiles.yml
/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
sudo cp pull-secret.json  /home/${KCLI_USER}/.generated/vmfiles
sudo cp pull-secret.json /root/.generated/vmfiles
sudo cp ${CERTIFICATE_PATH} /home/${KCLI_USER}/.generated/vmfiles/mirror-registry.${DOMAIN}.crt
sudo cp ${CERTIFICATE_PATH} /root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt
sudo cp ${KEY_PATH} /home/${KCLI_USER}/.generated/vmfiles/mirror-registry.${DOMAIN}.key
sudo cp ${KEY_PATH} /root/.generated/vmfiles/mirror-registry.${DOMAIN}.key
sudo rm pull-secret.json
#echo "Creating VM ${VM_NAME}"
#sudo kcli create vm -p mirror-registry ${VM_NAME} --wait