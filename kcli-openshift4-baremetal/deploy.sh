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


DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

function create(){
    sudo /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    #yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" > openshift_pull.json
    yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" | sudo tee openshift_pull.json >/dev/null

    #cat openshift_pull.json
    ln -s /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml  lab.yml
    yq eval ".domain = \"$DOMAIN\"" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml || exit $?
    /opt/kcli-pipelines/kcli-openshift4-baremetal/env-checks.sh  || exit $?
    cat lab.yml
    sudo kcli create plan --paramfile  lab.yml lab
    ##if [ $LAUNCH_STEPS == true ];
    ##then 
    ##    sudo kcli ssh lab-installer "sudo /root/scripts/launch_steps.sh"
    ##fi
    ##if [ $DISCONNECTED_INSTALL == true ];
    ##then 
    ##    sudo kcli ssh lab-installer "sudo /root/scripts/04_disconnected_quay.sh"
    ##   sudo kcli ssh lab-installer "sudo /root/scripts/04_disconnected_mirror.sh"
    ##    sudo kcli ssh lab-installer "sudo /root/scripts/04_disconnected_quay.sh"
    ##    sudo kcli ssh lab-installer "sudo /root/scripts/04_disconnected_olm.sh"
    ##fi
    ##if [ $DEPLOY_OPENSHIFT == true ];
    ##then 
    ##    sudo kcli ssh lab-installer "sudo /root/scripts/07_deploy_openshift.sh"
    ##fi
}


function destroy(){
    sudo kcli delete plan lab -y
    rm -rf lab.yml
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

