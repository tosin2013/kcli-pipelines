#!/bin/bash 

if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ ! -d /opt/openshift-agent-install ];
then 
    cd /opt/
    git clone https://github.com/tosin2013/openshift-agent-install.git
    cd openshift-agent-install
else
    cd /opt/openshift-agent-install
    git config pull.rebase false
    git config --global --add safe.directory /opt/openshift-agent-install
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

if [ ! -z ${FOLDER_NAME} ];
then
  FOLDER_NAME=${FOLDER_NAME}
else
  echo "FOLDER_NAME is not set"
  exit 1
fi

CLUSTER_FILE_PATH="/opt/openshift-agent-install/examples/${FOLDER_NAME}/cluster.yml"

function create(){
    ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    #yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" > openshift_pull.json
    ${USE_SUDO} yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" | sudo tee ~/ocp-install-pull-secret.json >/dev/null

    cat  ~/ocp-install-pull-secret.json
    dnf install nmstate -y
    ansible-galaxy install -r playbooks/collections/requirements.yml
    ./hack/create-iso.sh $FOLDER_NAME
    ./hack/deploy-on-kvm.sh examples/$FOLDER_NAME/nodes.yml
    ./bin/openshift-install agent wait-for bootstrap-complete --dir ./playbooks/generated_manifests/ocp4/ --log-level debug
    ./bin/openshift-install agent wait-for install-complete --dir ./playbooks/generated_manifests/ocp4/ --log-level debug
}


function destroy(){
    rm -rf /opt/openshift-agent-install/playbooks/generated_manifests/
    #export VM_PROFILE=freeipa
    #export VM_NAME="freeipa"
    #export  ACTION="delete" # create, delete

    #/opt/kcli-pipelines/deploy-vm.sh
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

