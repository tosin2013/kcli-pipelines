#!/bin/bash
set -euo pipefail
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
export ANSIBLE_HOST_KEY_CHECKING=False

# Function to check if VM exists
function vm_exists() {
    local vm_name=$1
    local exists=$(sudo kcli list vm | grep -c $vm_name)
    return $exists
}

# Function to check IDM
function check_idm() {
  local idm="$1"
  if curl --head --insecure --silent "https://$idm" > /dev/null; then
    echo "IDM is reachable over HTTPS."
  else
    echo "IDM is not reachable over HTTPS. Exiting."
    exit 1
  fi
}

# Function to return cloud user
function return_cloud_user() {
    local vm_name=$1
    case $vm_name in
        mirror-registry|openshift-jumpbox)
            echo "fedora"
            ;;
        microshift-demos|device-edge-workshops|ansible-aap|rhel9-pxe|rhel9-step-ca|rhel9|rhel8)
            echo "cloud-user"
            ;;
        *)
            echo "Unknown VM name"
            ;;
    esac
}

# Function to configure IDM container
function configure_idm_container() {
  local vm_name="$1"
  local dns_forwarder="$2"
  local domain_name=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

  if [ "$vm_name" == "freeipa" ]; then
    local ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}' | head -1)
    echo "VM $vm_name created with IP address $ip_address"

    if grep -q "$ip_address" /etc/hosts; then
      echo "$ip_address already exists in the hosts file."
    else
      sudo tee -a /etc/hosts <<EOF
$ip_address idm.${domain_name}
EOF
      echo "Added $ip_address to the hosts file."
    fi

    if grep -q "nameserver $ip_address" /etc/resolv.conf; then
      echo "$ip_address already exists in the resolv.conf file."
    else
      sudo tee /etc/resolv.conf <<EOF
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

# Function to handle VM creation
function create_vm() {
    local vm_name="$1"
    local action="$2"
    local domain_name=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

    if [[ $vm_name == "freeipa" ]]; then
        if vm_exists "$vm_name"; then
          sudo -E /opt/kcli-pipelines/freeipa/deploy-freeipa.sh create
        else
          echo "VM $vm_name already exists."
          sudo -E  /opt/kcli-pipelines/configure-dns.sh
          exit 0
        fi
    elif [[ $vm_name == "kcli-openshift4-baremetal" ]]; then
      sudo -E kcli-openshift4-baremetal/deploy.sh create
    elif [[ $vm_name == "ocp4-disconnected-helper" ]]; then
      sudo -E ocp4-disconnected-helper/deploy.sh create
    elif [[ $vm_name == "openshift-agent-install" ]]; then
      sudo -E openshift-agent-install/deploy.sh
    elif [[ $vm_name == "ceph-cluster" ]]; then
      sudo -E ceph-cluster/deploy.sh create
    elif [[ $vm_name == "kubernetes" ]]; then
      sudo -E kubernetes/deploy.sh create
    elif [[ $vm_name == "vyos-router" ]]; then
      sudo -E vyos-router/deploy.sh create
    else
        check_idm idm.$domain_name || exit $?
        local dns_address=$(sudo kcli info vm freeipa freeipa | grep ip: | awk '{print $2}' | head -1)
        local dns_forwarder=$(yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
        echo "Using DNS server $dns_address"
        if vm_exists "$vm_name"; then
          sudo kcli create vm -p $VM_PROFILE $vm_name -P dns=${dns_address} --wait  || exit $?
        else
          echo "VM $vm_name already exists."
        fi
        local ip_address=$(sudo kcli info vm $vm_name $vm_name | grep ip: | awk '{print $2}' | head -1)
        echo "VM $vm_name created with IP address $ip_address"
        sudo -E $ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
            --vault-password-file /root/.vault_password \
            --extra-vars "@${ANSIBLE_VAULT_FILE}" \
            --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
            --extra-vars "key=${vm_name}" \
            --extra-vars "freeipa_server_fqdn=idm.${domain_name}" \
            --extra-vars "value=${ip_address}" \
            --extra-vars "freeipa_server_domain=${domain_name}" \
            --extra-vars "action=present" -vvv
        local file_path="helper_scripts/hosts"
        if [ -f "$file_path" ]; then
            if grep -q "^\[$vm_name\]$" "$file_path"; then
                sudo sed -i "s/^\[$vm_name\]\n.*$/"'[$vm_name]\n'"$ip_address"/ "$file_path"
            else
                echo "[$vm_name]" | sudo tee -a  "$file_path"
                local target_user=$(return_cloud_user $vm_name)
                echo "$vm_name ansible_host=${ip_address} ansible_user=$target_user ansible_ssh_private_key_file=/root/.ssh/id_rsa" | sudo tee -a  "$file_path"
            fi
        else
            echo "[$vm_name]" | sudo tee  "$file_path"
            local target_user=$(return_cloud_user $vm_name)
            echo "$vm_name ansible_host=${ip_address} ansible_user=$target_user ansible_ssh_private_key_file=/root/.ssh/id_rsa" | sudo tee -a  "$file_path"
        fi
        $ANSIBLE_PLAYBOOK helper_scripts/update_dns.yaml -i helper_scripts/hosts \
            --extra-vars "target_hosts=${vm_name}" \
            --extra-vars "dns_server=${dns_address}" \
            --extra-vars "dns_server_two=${dns_forwarder}"
    fi
}

# Function to handle VM deletion
function delete_vm() {
    local vm_name="$1"
    local domain_name=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")

    if [[ $vm_name == "kcli-openshift4-baremetal" ]]; then
      kcli-openshift4-baremetal/deploy.sh delete
    elif [[ $vm_name == "freeipa" ]]; then
      /opt/kcli-pipelines/freeipa/deploy-freeipa.sh destroy
    elif [[ $vm_name == "ocp4-disconnected-helper" ]]; then
      /opt/kcli-pipelines/ocp4-disconnected-helper/destroy.sh
    elif [[ $vm_name == "vyos-router" ]]; then
       vyos-router/deploy.sh delete
    elif [[ $vm_name == "openshift-agent-install" ]]; then
      openshift-agent-install/deploy.sh destroy
    else
      local target_vm=$(sudo kcli list vm  | grep  ${vm_name} | awk '{print $2}')
      local ip_address=$(sudo kcli info vm $vm_name $vm_name | grep ip: | awk '{print $2}' | head -1)
      echo "Deleting VM $target_vm"
      if [ ! -z "$target_vm" ]; then
        sudo kcli delete vm $target_vm -y
      else
        echo "VM $vm_name does not exist."
      fi

      sudo -E $ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
          --vault-password-file /root/.vault_password \
          --extra-vars "@${ANSIBLE_VAULT_FILE}" \
          --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
          --extra-vars "key=${vm_name}" \
          --extra-vars "freeipa_server_fqdn=idm.${domain_name}" \
          --extra-vars "value=${ip_address}" \
          --extra-vars "freeipa_server_domain=${domain_name}" \
          --extra-vars "action=absent" -vvv
      sudo sed -i  '/\['$vm_name'\]/,+2d' helper_scripts/hosts
    fi
}

# Main function
function main() {
    IMAGE_PATH="/var/lib/libvirt/images/rhel8"

    # Check if the file or directory exists
    if [ -e "$IMAGE_PATH" ]; then
        echo "Success: '$IMAGE_PATH' exists."
        exit 0  # Exit with zero status to indicate success
    else
        echo "Error: '$IMAGE_PATH' does not exist."
        echo ""
        echo "Please SSH into the appropriate server and run the following commands to download the required RHEL images:"
        echo ""
        echo "  sudo kcli download image rhel8"
        echo "  sudo kcli download image rhel9"
        echo ""
        exit 1  # Exit with a non-zero status to indicate failure
    fi

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

    if [ $TARGET_SERVER == "equinix" ]; then
        if [ ! -f /home/lab-user/.local/bin/ansible-playbook ]; then
          pip3 install  --user ansible
        fi
        ANSIBLE_PLAYBOOK="sudo -E /home/lab-user/.local/bin/ansible-playbook"
    else
      ANSIBLE_PLAYBOOK="sudo -E ansible-playbook"
    fi

    cd /opt/kcli-pipelines
    DEFAULT_ENV_PATH="/opt/kcli-pipelines/helper_scripts/default.env"

    # Check if default.env exists, if not, create a default version
    if [ ! -f "${DEFAULT_ENV_PATH}" ]; then
      echo "default.env file does not exist, creating a default version..."
      cat <<EOF
    # Environment Variables for all scripts 

    KCLI_SAMPLES_DIR="/opt/kcli-pipelines/"
    NET_NAME=qubinet # qubinet default bridge name default for internal network
    export INVENTORY=localhost
    ANSIBLE_VAULT_FILE="/opt/qubinode_navigator/inventories/\${INVENTORY}/group_vars/control/vault.yml"
    ANSIBLE_ALL_VARIABLES="/opt/qubinode_navigator/inventories/\${INVENTORY}/group_vars/all.yml"
EOF
    fi

    # Source the default.env file
    source "${DEFAULT_ENV_PATH}"
    local domain_name=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
    echo "DOMAIN NAME: $domain_name" || exit $?

    case $ACTION in
        create)
            create_vm "$VM_NAME" "$ACTION"
            ;;
        delete)
            delete_vm "$VM_NAME"
            ;;
        deploy_app)
            echo "deploy app"
            ;;
        *)
            echo "Invalid action. Please set ACTION to create, delete, or deploy_app."
            exit 1
            ;;
    esac
}

main
