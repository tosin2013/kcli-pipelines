#!/bin/bash 

if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ ! -d /opt/ocp4-disconnected-helper ];
then 
    cd /opt/
    git clone https://github.com/tosin2013/ocp4-disconnected-helper.git
    cd ocp4-disconnected-helper
else
    cd /opt/ocp4-disconnected-helper
    git config pull.rebase false
    git config --global --add safe.directory /opt/ocp4-disconnected-helper
    git pull
fi 

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi


#DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

function deploy_harbor(){
  cd $KCLI_SAMPLES_DIR
IMAGE_NAME=ubuntu

/usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
  PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
  VM_NAME=harbor-$(echo $RANDOM | md5sum | head -c 5; echo;)
  DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
  DISK_SIZE=350
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
reservedns: ${DNS_FORWARDER}
domain: ${DOMAIN}
EOF

    sudo python3 profile_generator/profile_generator.py update-yaml ubuntu ubuntu/template.yaml  --vars-file /tmp/vm_vars.yaml
    #cat  kcli-profiles.yml
    /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
    sudo cp kcli-profiles.yml /home/${KCLI_USER}/.kcli/profiles.yml
    sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
}

deploy_harbor