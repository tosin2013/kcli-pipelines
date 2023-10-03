#!/bin/bash 
#set -e 
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
export ANSIBLE_HOST_KEY_CHECKING=False
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

if [ $TARGET_SERVER == "equinix" ];
then 
    #source ~/.profile
    #source ~/.bash_aliases
    if [ ! -f /home/lab-user/.local/bin/ansible-playbook ];
    then
      pip3 install  --user ansible
    fi 
    ANSIBLE_PLAYBOOK="sudo -E /home/lab-user/.local/bin/ansible-playbook"
else 
  ANSIBLE_PLAYBOOK="sudo -E /usr/local/bin/ansible-playbook"
fi 
# Define the check_idm function
function check_idm {
  local idm="$1"

  # Make an HTTPS request to the IDM server
  if curl --head --insecure --silent "https://$idm" > /dev/null; then
    echo "IDM is reachable over HTTPS."
  else
    echo "IDM is not reachable over HTTPS. Exiting."
    exit 1
  fi
}
# Define the return function
function return_cloud_user() {
    local vm_name=$1

    case $vm_name in
        mirror-registry)
            echo "fedora"
            ;;
        microshift-demos)
            echo "cloud-user"
            ;;
        openshift-jumpbox)
            echo "fedora"
            ;;
        device-edge-workshops)
            echo "cloud-user"
            ;;
        ansible-aap)
            echo "cloud-user"
            ;;
        rhel9)
            echo "cloud-user"
            ;;
        *)
            echo "Unknown VM name"
            ;;
    esac
}

# Define the configure_vm function
function configure_idm_container {
  local vm_name="$1"
  local dns_forwarder="$2"
  local domain_name=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

  if [ "$vm_name" == "freeipa-server-container" ]; then
    # Get the IP address of the VM
    local ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}' | head -1)

    echo "VM $vm_name created with IP address $ip_address"

    # Check if the IP address already exists in the hosts file
    if grep -q "$ip_address" /etc/hosts; then
      echo "$ip_address already exists in the hosts file."
    else
      # Add the IP address and hostname to the hosts file
      sudo tee -a /etc/hosts << EOF
$ip_address ipa.${domain_name}
EOF
      echo "Added $ip_address to the hosts file."
    fi

    # Check if the DNS server already exists in the resolv.conf file
    if grep -q "nameserver $ip_address" /etc/resolv.conf; then
      echo "$ip_address already exists in the resolv.conf file."
    else
      # Add the DNS server to the resolv.conf file
          # Add the IP address and hostname to the hosts file
    sudo tee /etc/resolv.conf << EOF
search ${domain_name}
domain ${domain_name}
nameserver $ip_address
nameserver $dns_forwarder
options rotate timeout:1
EOF
      echo "Added $ip_address to the resolv.conf file."
    fi
  fi
}


cd /opt/kcli-pipelines
source helper_scripts/default.env 
DOMAIN_NAME=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
echo "DOMAIN NAME: $DOMAIN_NAME" || exit $?
if [ $ACTION == "create" ];
then 
    echo "Creating VM $VM_NAME"

    if [[ $VM_NAME == "freeipa-server-container" ]];
    then
        sudo kcli create vm -p $VM_PROFILE $VM_NAME --wait
        IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}' | head -1)
        DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
        configure_idm_container "freeipa-server-container" $DNS_FORWARDER
    else
        check_idm ipa.$DOMAIN_NAME || exit $?
        DNS_ADDRESS=$(sudo kcli info vm freeipa-server-container freeipa-server-container | grep ip: | awk '{print $2}' | head -1)
        DNS_FORWARDER=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
        echo "Using DNS server $DNS_ADDRESS"
        sudo kcli create vm -p $VM_PROFILE $VM_NAME -P dns=${DNS_ADDRESS} --wait
        IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}' | head -1)
        echo "VM $VM_NAME created with IP address $IP_ADDRESS"
        $ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
            --vault-password-file "$HOME"/.vault_password \
            --extra-vars "@${ANSIBLE_VAULT_FILE}" \
            --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
            --extra-vars "key=${VM_NAME}" \
            --extra-vars "freeipa_server_fqdn=ipa.${DOMAIN_NAME}" \
            --extra-vars "value=${IP_ADDRESS}" \
            --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
            --extra-vars "action=present" -vvv
        #echo "[$VM_NAME]" | sudo tee -a helper_scripts/hosts 
        #echo "$IP_ADDRESS" | sudo tee -a helper_scripts/hosts

        file_path="helper_scripts/hosts"

        if [ -f "$file_path" ]; then
            if grep -q "^\[$VM_NAME\]$" "$file_path"; then
                echo "Content already exists. Replacing ip address."
                sudo sed -i "s/^\[$VM_NAME\]\n.*$/"'[$VM_NAME]\n'"$IP_ADDRESS"/ "$file_path"
            else
                echo "Content does not exist. Adding ip address."
                echo "[$VM_NAME]" | sudo tee -a  "$file_path"
                target_user=$(return_cloud_user $VM_NAME)
                echo "$VM_NAME ansible_host=${IP_ADDRESS} ansible_user=$target_user ansible_ssh_private_key_file=/root/.ssh/id_rsa" | sudo tee -a  "$file_path"
            fi
        else
            echo "File does not exist. Creating file with ip address."
            echo "[$VM_NAME]" | sudo tee  "$file_path"
            target_user=$(return_cloud_user $VM_NAME)
            echo "$VM_NAME ansible_host=${IP_ADDRESS} ansible_user=$target_user ansible_ssh_private_key_file=/root/.ssh/id_rsa" | sudo tee -a  "$file_path"
        fi
        $ANSIBLE_PLAYBOOK helper_scripts/update_dns.yaml -i helper_scripts/hosts \
            --extra-vars "target_hosts=${VM_NAME}" \
            --extra-vars "dns_server=${DNS_ADDRESS}" \
            --extra-vars "dns_server_two=${DNS_FORWARDER}"
    fi
elif [[ $ACTION == "delete" ]];
then 
    TARGET_VM=$(sudo kcli list vm  | grep  ${VM_NAME} | awk '{print $2}')
    IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}' | head -1)
    echo "Deleting VM $TARGET_VM"
    sudo kcli delete vm $TARGET_VM -y
    $ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
        --vault-password-file "$HOME"/.vault_password \
        --extra-vars "@${ANSIBLE_VAULT_FILE}" \
        --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
        --extra-vars "key=${VM_NAME}" \
        --extra-vars "freeipa_server_fqdn=ipa.${DOMAIN_NAME}" \
        --extra-vars "value=${IP_ADDRESS}" \
        --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
        --extra-vars "action=absent" -vvv
    sudo sed -i  '/\['$VM_NAME'\]/,+2d' helper_scripts/hosts
elif [[ $ACTION == "deploy_app" ]];
then 
  #sudo kcli scp /tmp/manifest_tower-dev_20230325T132029Z.zip device-edge-workshops:/tmp
  #./setup-demo-infra.sh
  echo "deploy app"
fi
