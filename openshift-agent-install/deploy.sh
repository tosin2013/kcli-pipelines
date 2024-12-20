#!/bin/bash 
set -x
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -euo pipefail
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
else
  export USE_SUDO=""
fi

#if [ ! -z "$CICD_PIPELINE" ]; then
# export USE_SUDO="sudo"
#fi

if [ ! -z ${FOLDER_NAME} ];
then
  FOLDER_NAME=${FOLDER_NAME}
else
  echo "FOLDER_NAME is not set"
  exit 1
fi

CLUSTER_FILE_PATH="/opt/openshift-agent-install/examples/${FOLDER_NAME}/cluster.yml"
export CLUSTER_NAME=$(yq eval '.cluster_name' "${CLUSTER_FILE_PATH}")
GENERATED_ASSET_PATH="${GENERATED_ASSET_PATH:-"${HOME}"}"

if [ ! -z ${ZONE_NAME} ];
then
  DOMAIN=${GUID}.${ZONE_NAME}
  ${USE_SUDO} yq e -i '.domain = "'${DOMAIN}'"' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/all.yml
  # Extract DNS servers from /etc/resolv.conf
  NEW_DNS_SERVER_1=$(grep -m 1 '^nameserver' /etc/resolv.conf | awk '{print $2}')
  NEW_DNS_SERVER_2=$(grep -m 2 '^nameserver' /etc/resolv.conf | tail -n 1 | awk '{print $2}')
  ${USE_SUDO} yq e -i '.dns_servers[0] = "'${NEW_DNS_SERVER_1}'" | .dns_servers[1] = "'${NEW_DNS_SERVER_2}'"' "/opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/all.yml"
  ${USE_SUDO} yq e -i '.base_domain = "'${DOMAIN}'"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i '.dns_servers[0] = "'${NEW_DNS_SERVER_1}'" | .dns_servers[1] = "'${NEW_DNS_SERVER_2}'"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i '.dns_search_domains[0] = "'${DOMAIN}'"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i 'del(.dns_search_domains[1])' ${CLUSTER_FILE_PATH}
  cat ${CLUSTER_FILE_PATH}
  sleep 5s
else
  DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
fi

function create(){
    #${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1

    # Check if the file contains the string $ANSIBLE_VAULT;1.1;AES256
    if grep -q '$ANSIBLE_VAULT;1.1;AES256' "$ANSIBLE_VAULT_FILE"; then
        echo "The file is encrypted with Ansible Vault. Decrypting the file..."
        ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
        if [ $? -eq 0 ]; then
            echo "File decrypted successfully."
        else
            echo "Failed to decrypt the file."
        fi
    else
        echo "The file is not encrypted with Ansible Vault."
    fi

    #yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" > openshift_pull.json
    ${USE_SUDO} yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}" | sudo tee ~/ocp-install-pull-secret.json >/dev/null

    ${USE_SUDO} cat  ~/ocp-install-pull-secret.json
    ${USE_SUDO} dnf install nmstate -y
    ${USE_SUDO} ansible-galaxy install -r playbooks/collections/requirements.yml
    export  GENERATED_ASSET_PATH="/root"
    ${USE_SUDO} ./hack/create-iso.sh $FOLDER_NAME || exit $?
    ${USE_SUDO} ./hack/deploy-on-kvm.sh examples/$FOLDER_NAME/nodes.yml || exit $?
    echo "To troubleshoot installation run the commands below in a separate terminal"
    echo "cd /opt/openshift-agent-install"
    echo "./bin/openshift-install agent wait-for bootstrap-complete --dir ${GENERATED_ASSET_PATH}/${CLUSTER_NAME}/ --log-level debug"
    echo "*********"
    sleep 15
    ${USE_SUDO} ./hack/watch-and-reboot-kvm-vms.sh examples/$FOLDER_NAME/nodes.yml
    ${USE_SUDO} ./bin/openshift-install agent wait-for install-complete --dir ${GENERATED_ASSET_PATH}/${CLUSTER_NAME}/ --log-level debug
}


function destroy(){
    ${USE_SUDO} ./hack/destroy-on-kvm.sh examples/$FOLDER_NAME/nodes.yml
    rm -rf /opt/openshift-agent-install/playbooks/generated_manifests/
    rm -rf /root/${FOLDER_NAME}
    export VM_PROFILE=freeipa
    export VM_NAME="freeipa"
    export  ACTION="delete" # create, delete

    ${USE_SUDO} /opt/kcli-pipelines/deploy-vm.sh
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

