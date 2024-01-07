#!/bin/bash 
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi


DOMAIN_NAME=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")



cat /opt/kcli-pipelines/kubernetes/kubernetes.yml
kcli create plan -f  /opt/kcli-pipelines/kubernetes/kubernetes.yml
sudo -E /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
# Loop over each VM in the ceph-cluster.yml file
for VM_NAME in $(yq eval '. | keys | .[]' /opt/kcli-pipelines/kubernetes/kubernetes.yml); do
  # Get the IP address of the VM
  IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}' | head -1)
  echo "VM $VM_NAME created with IP address $IP_ADDRESS"
  
  ANSIBLE_PLAYBOOK="sudo -E /usr/local/bin/ansible-playbook"

  # Update the DNS using the add_ipa_entry.yaml playbook
  $ANSIBLE_PLAYBOOK /opt/kcli-pipelines/helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=${IP_ADDRESS}" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" --extra-vars "action=present" -vvv || exit $?

done
sudo -E /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1