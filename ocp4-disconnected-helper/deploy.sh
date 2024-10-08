#!/bin/bash 
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe
if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
  source helper_scripts/helper_functions.sh
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

# SETUP_HARBER_REGISTRY does not exist exit 
if [ -z "$SETUP_HARBER_REGISTRY" ];
then 
    echo "SETUP_HARBER_REGISTRY does not exist"
    exit 1
fi

# DOWNLOAD_TO_TAR does not exist exit
if [ -z "$DOWNLOAD_TO_TAR" ];
then 
    echo "DOWNLOAD_TO_TAR does not exist"
    exit 1
fi

# PUSH_TAR_TO_REGISTRY does not exist exit
if [ -z "$PUSH_TAR_TO_REGISTRY" ];
then 
    echo "PUSH_TAR_TO_REGISTRY does not exist"
    exit 1
fi


# if SETUP_HARBER_REGISTRY is set to true, then run the playbook
if [ "${SETUP_HARBER_REGISTRY}" == "true" ];
then 
  DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

  cd  /opt/ocp4-disconnected-helper

  if ${USE_SUDO}  kcli list vms | grep -oq 'harbor'; then
     echo "Found 'harbor' in the output"
     ${USE_SUDO}  kcli ssh harbor sudo  cat  /etc/letsencrypt/live/harbor.${DOMAIN}/fullchain.pem > /tmp/harbor.${DOMAIN}.bundle.crt
     ${USE_SUDO}  kcli ssh harbor sudo  cat  /etc/letsencrypt/live/harbor.${DOMAIN}/privkey.pem > /tmp/harbor.${DOMAIN}.key
  else
      echo "'harbor' not found in the output"
      exit 1
  fi

  # Convert YAML to JSON
  ${USE_SUDO} yq eval -o=json '.' extra_vars/setup-harbor-registry-vars.yml  > /tmp/output.json
  # CHOWN OF /tmp/output.json
  ${USE_SUDO} chown runner:users /tmp/output.json || exit $?

  # Load the certificate contents into a shell variable
  certificate=$(${USE_SUDO} cat /tmp/harbor.${DOMAIN}.bundle.crt)
  certificate_key=$(${USE_SUDO} cat harbor.${DOMAIN}.key)

  ${USE_SUDO} cat /tmp/harbor.${DOMAIN}.bundle.crt > /dev/null 2>&1 || exit $?
  ${USE_SUDO} cat harbor.${DOMAIN}.key > /dev/null 2>&1 || exit $?

  # Use jq to update the ssl_certificate field with the certificate
  ${USE_SUDO} jq --arg cert "$certificate" '.ssl_certificate = $cert' /tmp/output.json > /tmp/1.json || exit $?
  # CHOWN OF /tmp/1.json
  ${USE_SUDO} chown runner:users /tmp/1.json|| exit $?
  ${USE_SUDO} jq --arg cert "$certificate_key" '.ssl_certificate_key = $cert' /tmp/1.json > /tmp/test_new.json || exit $?

  # Convert JSON back to YAML
  ${USE_SUDO} yq eval --output-format=yaml '.' /tmp/test_new.json > output.yaml || exit $?
  ${USE_SUDO} yq eval '.harbor_hostname = "harbor.'${DOMAIN}'"' -i output.yaml || exit $?
  IP_ADDRESS=$(${USE_SUDO} /usr/bin/kcli info vm harbor | grep ip: | awk '{print $2}')

  ${USE_SUDO} sshpass -p "$SSH_PASSWORD" ${USE_SUDO} ssh-copy-id -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no cloud-user@${IP_ADDRESS} || exit $?
  ${USE_SUDO}  tee /tmp/inventory <<EOF
## Ansible Inventory template file used by Terraform to create an ./inventory file populated with the nodes it created

[harbor]
${VM_NAME}.${DOMAIN}

[all:vars]
ansible_ssh_private_key_file=/root/.ssh/id_rsa
ansible_ssh_user=cloud-user
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_internal_private_ip=${IP_ADDRESS}
EOF

  ${USE_SUDO} cat /tmp/inventory


  ${USE_SUDO} /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/setup-harbor-registry.yml  -e "@output.yaml" -vv || exit $?
  exit 0
fi

# if DOWNLOAD_TO_TAR is set to true, then run the playbook
if [ "${DOWNLOAD_TO_TAR}" == "true" ];
then 
    if [ -d /opt/images/ ];
    then 
        ${USE_SUDO} rm -rf /opt/images/
    fi
    DOMAIN=$(yq eval '.domain' "${GUID}.${ANSIBLE_ALL_VARIABLES}")
    curl --fail https://harbor.${DOMAIN}/ || exit $?
    echo "Downloading images to /opt/images"
    cd  /opt/ocp4-disconnected-helper
    echo   ${USE_SUDO} /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/download-to-tar.yml  -e "@extra_vars/download-to-tar-vars.yml" -vv
    ${USE_SUDO} /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/download-to-tar.yml  -e "@extra_vars/download-to-tar-vars.yml" -vv || exit $?
    exit 0
fi

#if PUSH_TAR_TO_REGISTRY is set to true, then run the playbook
if [ "${PUSH_TAR_TO_REGISTRY}" == "true" ];
then 
    DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
    curl --fail https://harbor.${DOMAIN}/ || exit $?
    echo "Pushing images to registry"
    cd  /opt/ocp4-disconnected-helper
    ${USE_SUDO} yq eval '.registries[0].server = "harbor.'${DOMAIN}'"' -i extra_vars/push-tar-to-registry-vars.yml || exit $?
    echo ${USE_SUDO} /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/push-tar-to-registry.yml  -e "@extra_vars/push-tar-to-registry-vars.yml" -vv 
    ${USE_SUDO} /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/push-tar-to-registry.yml  -e "@extra_vars/push-tar-to-registry-vars.yml" -vv || exit $?
    exit 0
fi
