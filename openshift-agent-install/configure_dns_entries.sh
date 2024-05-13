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
  ${USE_SUDO} yq e -i '.dns_search_domains[0] = "'${DOMAIN}'"' ${CLUSTER_FILE_PATH}
  ${USE_SUDO} yq e -i 'del(.dns_search_domains[1])' ${CLUSTER_FILE_PATH}
else
  DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
fi

export vm_name="freeipa"
export ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}' | head -1)
${USE_SUDO} sudo yq e '(.dns_servers[0]) = "'${ip_address}'"' -i ${CLUSTER_FILE_PATH}

function create_dns_entries(){
    ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    API_ENDPOINT=$(yq eval '.api_vips' "$CLUSTER_FILE_PATH" | sed 's/^- //')
    CLUSTER_NAME=$(yq eval '.cluster_name' "$CLUSTER_FILE_PATH")
    APPS_ENDPOINT=$(yq eval '.app_vips' "$CLUSTER_FILE_PATH" | sed 's/^- //')
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