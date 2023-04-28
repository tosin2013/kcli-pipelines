#!/bin/bash 
set -e 
if [ -z "$VM_NAME" ]; then
    echo "Error: Please provide the name of the VM to deploy by setting the VM_NAME environment variable."
    echo "Example: export VM_NAME=my-vm"
    exit 1
fi

if [ -z "$ACTION" ]; then
    echo "Error: Please provide an action to perform by setting the ACTION environment variable to create, delete, or deploy_app."
    echo "Example: export ACTION=deploy_app"
    exit 1
fi

cd /opt/kcli-pipelines
source helper_scripts/default.env 
DOMAIN_NAME=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

if [ $ACTION == "create" ];
then 
    echo "Creating VM $VM_NAME"
    sudo kcli create vm -p $VM_NAME $VM_NAME --wait
    IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}')
    echo "VM $VM_NAME created with IP address $IP_ADDRESS"
    sudo -E ansible-playbook helper_scripts/add_ipa_entry.yaml \
        --vault-password-file "$HOME"/.vault_password \
        --extra-vars "@${ANSIBLE_VAULT_FILE}" \
        --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
        --extra-vars "key=${VM_NAME}" \
        --extra-vars "freeipa_server_fqdn=${VM_NAME}.${DOMAIN_NAME}" \
        --extra-vars "value=${IP_ADDRESS}" \
        --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
        --extra-vars "action=present" 
elif [ $ACTION == "delete" ];
then 
    TARGET_VM=$(kcli list vm  | grep  ${VM_NAME} | awk '{print $2}')
    IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}')
    echo "Deleting VM $TARGET_VM"
    kcli delete vm $TARGET_VM -y
    sudo -E ansible-playbook helper_scripts/add_ipa_entry.yaml \
        --vault-password-file "$HOME"/.vault_password \
        --extra-vars "@${ANSIBLE_VAULT_FILE}" \
        --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
        --extra-vars "key=${VM_NAME}" \
        --extra-vars "freeipa_server_fqdn=${VM_NAME}.${DOMAIN_NAME}" \
        --extra-vars "value=${IP_ADDRESS}" \
        --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
        --extra-vars "action=absent" 
elif [ $ACTION == "deploy_app" ];
then 
  #sudo kcli scp /tmp/manifest_tower-dev_20230325T132029Z.zip device-edge-workshops:/tmp
  #./setup-demo-infra.sh
  echo "deploy app"
fi

