#!/bin/bash 

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

if [ ! -d /opt/freeipa-workshop-deployer ];
then 
    cd /opt/
    git clone https://github.com/karmab/kcli-openshift4-baremetal
    cd kcli-openshift4-baremetal
else
  cd /opt/kcli-openshift4-baremetal
  git config pull.rebase false
  git pull
fi 

function create(){
    /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}") > $HOME/pull-secret.json
    vim $HOME/openshift_pull.json
    ln -s paramfiles/lab.yml  lab.yml
    kcli create plan --paramfile  lab.yml lab
}


function destroy(){
    kcli delete plan lab
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

