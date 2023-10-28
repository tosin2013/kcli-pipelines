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


DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
export VM_PROFILE=harbor
export VM_NAME="harbor"
export  ACTION="create" # create, delete

/opt/kcli-pipelines/deploy-vm.sh
IP_ADDRESS=$(${USE_SUDO} /usr/bin/kcli info vm harbor | grep ip: | awk '{print $2}')

${USE_SUDO} sshpass -p "$SSH_PASSWORD" ${USE_SUDO} ssh-copy-id -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no cloud-user@${IP_ADDRESS} || exit $?

cd  /opt/ocp4-disconnected-helper
if [[ -f /opt/ocp4-disconnected-helper/playbooks/inventory.org ]];
then 
    ${USE_SUDO} cp /opt/ocp4-disconnected-helper/playbooks/inventory.org /opt/ocp4-disconnected-helper/playbooks/inventory
else 
    ${USE_SUDO} cp /opt/ocp4-disconnected-helper/playbooks/inventory.org /opt/ocp4-disconnected-helper/playbooks/inventory
fi
${USE_SUDO} sed 's/disconn-harbor.d70.kemo.labs/'${VM_NAME}.${DOMAIN}'/g' /opt/ocp4-disconnected-helper/playbooks/inventory
${USE_SUDO} sed 's/192.168.71.240/'${IP_ADDRESS}'/g'/opt/ocp4-disconnected-helper/playbooks/inventory
${USE_SUDO} sed 's/notken/cloud-user/g' playbooks/inventory

/usr/local/bin/ansible-playbook -i /opt/ocp4-disconnected-helper/playbooks/inventory /opt/ocp4-disconnected-helper/playbooks/setup-harbor-registry.yml -vvv