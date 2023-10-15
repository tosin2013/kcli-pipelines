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


DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

function create(){
    /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    #yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" > openshift_pull.json
    yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" | sudo tee openshift_pull.json >/dev/null

    #cat openshift_pull.json
    ln -s /opt/quibinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml  lab.yml
    yq eval ".domain = \"$DOMAIN\"" -i /opt/quibinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml || exit $?
    /opt/kcli-pipelines/kcli-openshift4-baremetal/env-checks.sh  || exit $?
    cat lab.yml
    sudo kcli create plan --paramfile  lab.yml lab
}


function destroy(){
    sudo kcli delete plan lab -y
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

