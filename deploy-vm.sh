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

# Define the configure_vm function
function configure_vm {
  local vm_name="$1"

  if [ "$vm_name" == "freeipa-server-container" ]; then
    # Get the IP address of the VM
    local ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}')

    echo "VM $vm_name created with IP address $ip_address"

    # Check if the IP address already exists in the hosts file
    if grep -q "$ip_address" /etc/hosts; then
      echo "$ip_address already exists in the hosts file."
    else
      # Add the IP address and hostname to the hosts file
      sudo tee -a /etc/hosts << EOF
$ip_address $vm_name
EOF
      echo "Added $ip_address to the hosts file."
    fi

    # Check if the DNS server already exists in the resolv.conf file
    if grep -q "nameserver $ip_address" /etc/resolv.conf; then
      echo "$ip_address already exists in the resolv.conf file."
    else
      # Add the DNS server to the resolv.conf file
    sudo tee -a /etc/resolv.conf << EOF
nameserver $ip_address
EOF
      echo "Added $ip_address to the resolv.conf file."
    fi
  fi
}

# Define the configure_vm function
function configure_idm_container {
  local vm_name="$1"

  if [ "$vm_name" == "freeipa-server-container" ]; then
    # Get the IP address of the VM
    local ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}')

    echo "VM $vm_name created with IP address $ip_address"

    # Check if the IP address already exists in the hosts file
    if grep -q "$ip_address" /etc/hosts; then
      echo "$ip_address already exists in the hosts file."
    else
      # Add the IP address and hostname to the hosts file
      sudo tee -a /etc/hosts << EOF
$ip_address $vm_name
EOF
      echo "Added $ip_address to the hosts file."
    fi

    # Check if the DNS server already exists in the resolv.conf file
    if grep -q "nameserver $ip_address" /etc/resolv.conf; then
      echo "$ip_address already exists in the resolv.conf file."
    else
      # Add the DNS server to the resolv.conf file
          # Add the IP address and hostname to the hosts file
    sudo tee -a /etc/resolv.conf << EOF
nameserver $ip_address
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
        sudo kcli create vm -p $VM_NAME $VM_NAME --wait
        IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}')
        configure_idm_container "freeipa-server-container"
    else
        check_idm $IP_ADDRESS || exit $?
        sudo kcli create vm -p $VM_NAME $VM_NAME --wait
        IP_ADDRESS=$(sudo kcli info vm $VM_NAME $VM_NAME | grep ip: | awk '{print $2}')
        echo "VM $VM_NAME created with IP address $IP_ADDRESS"
        sudo -E ansible-playbook helper_scripts/add_ipa_entry.yaml \
            --vault-password-file "$HOME"/.vault_password \
            --extra-vars "@${ANSIBLE_VAULT_FILE}" \
            --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
            --extra-vars "key=${VM_NAME}" \
            --extra-vars "freeipa_server_fqdn=ipa.${DOMAIN_NAME}" \
            --extra-vars "value=${IP_ADDRESS}" \
            --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
            --extra-vars "action=present" -vvv
    fi
elif [[ $ACTION == "delete" ]];
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
        --extra-vars "freeipa_server_fqdn=ipa.${DOMAIN_NAME}" \
        --extra-vars "value=${IP_ADDRESS}" \
        --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
        --extra-vars "action=absent" -vvv
elif [[ $ACTION == "deploy_app" ]];
then 
  #sudo kcli scp /tmp/manifest_tower-dev_20230325T132029Z.zip device-edge-workshops:/tmp
  #./setup-demo-infra.sh
  echo "deploy app"
fi