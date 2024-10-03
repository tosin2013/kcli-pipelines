#!/bin/bash 

DEFAULT_ENV_PATH="${HOME}/kcli-pipelines/helper_scripts/default.env"

# Check if default.env exists, if not, create a default version
if [ ! -f "${DEFAULT_ENV_PATH}" ]; then
  echo "default.env file does not exist, creating a default version..."
  cat <<EOF > "${DEFAULT_ENV_PATH}"
# Environment Variables for all scripts 

KCLI_SAMPLES_DIR="\${HOME}/kcli-pipelines/"
NET_NAME=qubinet # qubinet default bridge name default for internal network
export INVENTORY=localhost
ANSIBLE_VAULT_FILE="/opt/qubinode_navigator/inventories/\${INVENTORY}/group_vars/control/vault.yml"
ANSIBLE_ALL_VARIABLES="/opt/qubinode_navigator/inventories/\${INVENTORY}/group_vars/all.yml"
EOF
fi

# Source the default.env file
source "${DEFAULT_ENV_PATH}"

if [ ! -d ${HOME}/kcli-openshift4-baremetal ];
then 
    cd ${HOME}
    git clone https://github.com/karmab/kcli-openshift4-baremetal
    cd kcli-openshift4-baremetal
else
    cd ${HOME}/kcli-openshift4-baremetal 
    git config pull.rebase false
    git config --global --add safe.directory ${HOME}/kcli-openshift4-baremetal 
    git pull
fi 

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi

if [ ! -z ${ZONE_NAME} ];
then
  DOMAIN=${GUID}.${ZONE_NAME}
  ${USE_SUDO} yq e -i '.domain = "'${DOMAIN}'"' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/all.yml
else
  DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
fi

function create(){
    ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    #yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" > openshift_pull.json
    ${USE_SUDO} yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" | sudo tee openshift_pull.json >/dev/null

    #cat openshift_pull.json
    ${USE_SUDO} ln -s /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  lab.yml
    ${USE_SUDO} yq eval ".domain = \"$DOMAIN\"" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG} || exit $?
    ${USE_SUDO} ${HOME}/kcli-pipelines/kcli-openshift4-baremetal/env-checks.sh  || exit $?
    cat lab.yml
    ${USE_SUDO} kcli create plan --paramfile  lab.yml lab
}


function destroy(){
    ${USE_SUDO} kcli delete plan lab --y
    ${USE_SUDO} rm -rf lab.yml
    export VM_PROFILE=freeipa
    export VM_NAME="freeipa"
    export  ACTION="delete" # create, delete

    ${HOME}/kcli-pipelines/deploy-vm.sh
}

if [ $ACTION == "create" ];
then 
  create
elif [ $ACTION == "delete" ]; 
then 
  destroy
else 
  echo "help"
fi

