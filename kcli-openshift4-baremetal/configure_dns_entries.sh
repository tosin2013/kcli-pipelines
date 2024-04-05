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

function create_dns_entries(){
    ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    API_ENDPOINT=$(yq eval '. | .api_ip' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG})
    CLUSTER_NAME=$(yq eval '. | .cluster' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG})
    APPS_ENDPOINT=$(yq eval '. | .ingress_ip' /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG})
    ANSIBLE_PLAYBOOK="sudo -E /usr/local/bin/ansible-playbook"
    DOMAIN_NAME=api.${CLUSTER_NAME}.${DOMAIN}
    # Update the DNS using the add_ipa_entry.yaml playbook
    $ANSIBLE_PLAYBOOK /opt/kcli-pipelines/helper_scripts/add_ipa_entry.yaml \
      --vault-password-file "$HOME"/.vault_password \
      --extra-vars "@${ANSIBLE_VAULT_FILE}" \
      --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
      --extra-vars "key=api.${CLUSTER_NAME}" \
      --extra-vars "freeipa_server_fqdn=idm.${DOMAIN}" \
      --extra-vars "value=${API_ENDPOINT}" \
      --extra-vars "freeipa_server_domain=${DOMAIN}" --extra-vars "action=present" -vvv || exit $?

    DOMAIN_NAME=*.apps.${CLUSTER_NAME}.${DOMAIN}
    $ANSIBLE_PLAYBOOK /opt/kcli-pipelines/helper_scripts/add_ipa_entry.yaml \
      --vault-password-file "$HOME"/.vault_password \
      --extra-vars "@${ANSIBLE_VAULT_FILE}" \
      --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
      --extra-vars "key=*.apps.${CLUSTER_NAME}" \
      --extra-vars "freeipa_server_fqdn=idm.${DOMAIN}" \
      --extra-vars "value=${APPS_ENDPOINT}" \
      --extra-vars "freeipa_server_domain=${DOMAIN}" --extra-vars "action=present" -vvv || exit $?

      # replace nameserver 127.0.0.1 in /etc/resolv.conf with the ipa server
      # this is needed for the installer to be able to resolve the api and apps endpoints
      /opt/kcli-pipelines/configure-dns.sh
}

create_dns_entries