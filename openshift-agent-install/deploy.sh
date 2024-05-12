#!/bin/bash 

if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ ! -d /opt/kcli-openshift4-baremetal ];
then 
    cd /opt/
    git clone https://github.com/karmab/kcli-openshift4-baremetal
    cd kcli-openshift4-baremetal
else
    cd /opt/kcli-openshift4-baremetal
    git config pull.rebase false
    git config --global --add safe.directory /opt/kcli-openshift4-baremetal
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
  DOMAIN=${ZONE_NAME}
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
    ${USE_SUDO} /opt/kcli-pipelines/kcli-openshift4-baremetal/env-checks.sh  || exit $?
    cat lab.yml
    ${USE_SUDO} kcli create plan --paramfile  lab.yml lab
}


function destroy(){
    ${USE_SUDO} kcli delete plan lab --y
    ${USE_SUDO} rm -rf lab.yml
    export VM_PROFILE=freeipa
    export VM_NAME="freeipa"
    export  ACTION="delete" # create, delete

    /opt/kcli-pipelines/deploy-vm.sh
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

