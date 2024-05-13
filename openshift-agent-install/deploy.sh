#!/bin/bash 
set -x
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
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

if [ ! -z ${FOLDER_NAME} ];
then
  FOLDER_NAME=${FOLDER_NAME}
else
  echo "FOLDER_NAME is not set"
  exit 1
fi

CLUSTER_FILE_PATH="/opt/openshift-agent-install/examples/${FOLDER_NAME}/cluster.yml"

if [ ! -z ${ZONE_NAME} ];
then
  DOMAIN=${GUID}.${ZONE_NAME}
  ${USE_SUDO} yq e -i '.domain = "'${DOMAIN}'"' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/all.yml
  ${USE_SUDO} yq e -i '.base_domain = "'${DOMAIN}'"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i '.dns_servers[0] = "8.8.8.8"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i '.dns_search_domains[0] = "'${DOMAIN}'"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i 'del(.dns_search_domains[1])' ${CLUSTER_FILE_PATH}
  cat ${CLUSTER_FILE_PATH}
  exit 1
else
  DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
fi

function create(){
    ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    #yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" > openshift_pull.json
    ${USE_SUDO} yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" | sudo tee ~/ocp-install-pull-secret.json >/dev/null

    cat  ~/ocp-install-pull-secret.json
    dnf install nmstate -y
    ansible-galaxy install -r playbooks/collections/requirements.yml
    ./hack/create-iso.sh $FOLDER_NAME
    ./hack/deploy-on-kvm.sh examples/$FOLDER_NAME/nodes.yml
    echo "To troubleshoot installation run the commands below in a separate terminal"
    echo "./bin/openshift-install agent wait-for bootstrap-complete --dir ./playbooks/generated_manifests/ocp4/ --log-level debug"
    echo "*********"
    sleep 15
    ./hack/watch-and-reboot-kvm-vms.sh examples/$FOLDER_NAME/nodes.yml
    ./bin/openshift-install agent wait-for install-complete --dir ./playbooks/generated_manifests/ocp4/ --log-level debug
}


function destroy(){
    ./hack/destroy-on-kvm.sh examples/$FOLDER_NAME/nodes.yml
    rm -rf /opt/openshift-agent-install/playbooks/generated_manifests/
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

