#!/bin/bash
set -euo pipefail
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

# Function to log messages
# This script defines a logging function `log` that prints messages with a timestamp.
# The timestamp is formatted as ISO 8601 (e.g., 2023-10-05T14:48:00+0000).
# Usage: log "Your message here"
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

# This function retrieves the operating system version from the /etc/os-release file.
# If the file exists, it sources the file to extract the OS and VERSION_ID variables.
# If the file does not exist, it logs an error message and exits with status code 1.
# Globals:
#   OS - The ID of the operating system (e.g., ubuntu, centos).
#   VERSION_ID - The version ID of the operating system (e.g., 20.04, 7).
# Arguments:
#   None
# Outputs:
#   Writes an error message to the log if /etc/os-release is not found.
# Returns:
#   None
get_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        log "Cannot determine OS version. /etc/os-release not found."
        exit 1
    fi
}


# This function determines the appropriate command to update YAML files based on the operating system and its version.
# It first retrieves the OS version by calling the get_os_version function.
# Then, it checks if the OS is either CentOS, RHEL, or Rocky Linux.
# If the OS is one of these, it further checks the version:
# - For version 8.x, it sets the COMMAND variable to "update-yaml".
# - For version 9.x, it sets the COMMAND variable to "update_yaml".
# If the version is unsupported, it logs an error message and exits with status 1.
# If the OS is unsupported, it logs an error message and exits with status 1.
determine_command_yaml() {
    get_os_version

    if [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "rocky" ]]; then
        if [[ "$VERSION_ID" == 8* ]]; then
            COMMAND="update-yaml"
        elif [[ "$VERSION_ID" == 9* ]]; then
            COMMAND="update_yaml"
        else
            log "Unsupported version: $VERSION_ID"
            exit 1
        fi
    else
        log "Unsupported OS: $OS"
        exit 1
    fi
}


# This script defines a function `clone_or_pull_repo` that clones or pulls a Git repository.
#
# The function performs the following steps:
# 1. Sets the Git repository URL to `https://github.com/tosin2013/kcli-pipelines.git`.
# 2. Checks if the `TARGET_SERVER` environment variable is set. If not, logs an error message and exits with status 1.
# 3. Checks if the directory `/opt/kcli-pipelines` exists:
#    - If the directory does not exist, it clones the repository into `/opt/kcli-pipelines` using `sudo`.
#    - If the directory exists, it changes the current directory to `/opt/kcli-pipelines` and pulls the latest changes from the repository using `sudo`.
# 4. Logs an error message and exits with status 1 if either the clone or pull operation fails.
clone_or_pull_repo() {
    GIT_REPO=https://github.com/tosin2013/kcli-pipelines.git

    if [ -z "$TARGET_SERVER" ]; then
        log "TARGET_SERVER variable is not set"
        exit 1
    fi

    if [ ! -d "/opt/kcli-pipelines" ]; then
        sudo git clone "$GIT_REPO" "/opt/kcli-pipelines" || { log "Failed to clone repo"; exit 1; }
    else
        cd "/opt/kcli-pipelines"
        sudo git pull || { log "Failed to pull repo"; exit 1; }
    fi
}


# This script configures the environment for kcli-pipelines.
# It performs the following tasks:
# 1. If the TARGET_SERVER is "rhel8-equinix" or "rhel9-equinix", it updates the NET_NAME in the default.env file to "default".
# 2. If the VM_PROFILE is "kcli-openshift4-baremetal", it updates the NET_NAME in the default.env file to "lab-baremetal".
# 3. Checks if an SSH key exists at ~/.ssh/id_rsa. If not, it generates a new RSA SSH key with 4096 bits.
#    If the SSH key exists, it starts the ssh-agent and adds the SSH key to the agent.
# 4. Checks if the ansible.cfg file exists at /opt/kcli-pipelines. If not, it creates a new ansible.cfg file with a specified remote_tmp directory.
# 5. Sources the helper_functions.sh script from the helper_scripts directory.
configure_environment() {
    if [ "$TARGET_SERVER" == "rhel8-equinix" ] || [ "$TARGET_SERVER" == "rhel9-equinix" ]; then
        sudo sed -i 's/NET_NAME=qubinet/NET_NAME=default/g' "/opt/kcli-pipelines/helper_scripts/default.env"
    fi

    if [ "$VM_PROFILE" == "kcli-openshift4-baremetal" ]; then
        sudo sed -i 's/NET_NAME=.*/NET_NAME=lab-baremetal/g' "/opt/kcli-pipelines/helper_scripts/default.env"
    fi

    if [ ! -f ~/.ssh/id_rsa ]; then
        log "SSH key does not exist"
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "kcli-pipelines@${HOSTNAME}"
    else
        eval $(ssh-agent)
        ssh-add ~/.ssh/id_rsa
    fi

    if [ ! -f "/opt/kcli-pipelines/ansible.cfg" ]; then
        cat >"/opt/kcli-pipelines/ansible.cfg" <<EOF
[defaults]
remote_tmp = /tmp/ansible-$USER
EOF
    fi

    source "/opt/kcli-pipelines/helper_scripts/helper_functions.sh"
}

# Function to generate profiles
# This script generates KCLI profiles for different operating systems.
# It performs the following steps:
# 1. Changes the current directory to /opt/kcli-pipelines.
# 2. Updates the INVENTORY variable in the helper_scripts/default.env file to the value of TARGET_SERVER.
# 3. Sources the updated environment variables from helper_scripts/default.env.
# 4. Retrieves the KCLI user from the ANSIBLE_ALL_VARIABLES file using yq and logs the user.
# 5. Removes any existing KCLI profiles configuration files from the user's home directory and root's home directory.
# 6. Calls the determine_command_yaml function to set the COMMAND variable.
# 7. Generates KCLI profiles for rhel8, rhel9, fedora39, and centos9stream using the profile_generator.py script with the appropriate template and variables files.
generate_profiles() {
    cd "/opt/kcli-pipelines"

    sudo sed -i "s|export INVENTORY=localhost|export INVENTORY='${TARGET_SERVER}'|g" helper_scripts/default.env
    source helper_scripts/default.env
    KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
    log "KCLI USER: $KCLI_USER" || { log "Failed to get KCLI_USER"; exit 1; }
    sudo rm -rf ~/.kcli/profiles.yml
    sudo rm -f /root/.kcli/profiles.yml
    determine_command_yaml
    sudo python3 profile_generator/profile_generator.py "$COMMAND" rhel8 rhel8/template.yaml --vars-file rhel8/vm_vars.yml
    sudo python3 profile_generator/profile_generator.py "$COMMAND" rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
    sudo python3 profile_generator/profile_generator.py "$COMMAND" fedora39 fedora39/template.yaml --vars-file fedora39/vm_vars.yaml
    sudo python3 profile_generator/profile_generator.py "$COMMAND" centos9stream centos9stream/template.yaml --vars-file centos9stream/vm_vars.yaml
}

# This script configures kcli profiles for different users and environments.
# It performs the following steps:
# 1. Checks if the .kcli directory exists for the specified users ($KCLI_USER, $USER, and root).
#    If not, it creates the directory.
# 2. Checks if the kcli-profiles.yml file exists in the /opt/kcli-pipelines directory.
#    If not, it logs an error and exits.
# 3. Copies the kcli-profiles.yml file to the .kcli directory for each user.
# 4. Executes the configure-kcli-profile.sh script for various environments (openshift-jumpbox, ansible-aap,
#    device-edge-workshops, microshift-demos, kubernetes, jupyterlab, ceph-cluster, rhel9-pxe, step-ca-server, ubuntu).
#    If any script fails, it logs an error and exits.
# 5. If the CUSTOM_PROFILE variable is set to "true" and the VM_PROFILE is not "freeipa", it configures the specified
#    VM_PROFILE type by executing the corresponding configure-kcli-profile.sh script.
# 6. Copies the resulting profiles.yml file to the .kcli directory for each user.
configure_kcli_profiles() {
    if [ ! -d "/home/$KCLI_USER/.kcli" ]; then
        log "/home/$KCLI_USER/.kcli directory does not exist"
        sudo mkdir -p "/home/$KCLI_USER/.kcli"
    fi

    if [ ! -d "/home/$USER/.kcli" ]; then
        log "/home/$USER/.kcli directory does not exist"
        sudo mkdir -p "/home/$USER/.kcli"
    fi

    if [ ! -d /root/.kcli ]; then
        log "/root/.kcli directory does not exist"
        sudo mkdir -p /root/.kcli
    fi

    if [ ! -f "/opt/kcli-pipelines/kcli-profiles.yml" ]; then
        log "kcli-profiles.yml file does not exist"
        exit 1
    fi

    sudo cp "/opt/kcli-pipelines/kcli-profiles.yml" "/home/$KCLI_USER/.kcli/profiles.yml"
    sudo cp "/opt/kcli-pipelines/kcli-profiles.yml" "/home/$USER/.kcli/profiles.yml"
    sudo cp "/opt/kcli-pipelines/kcli-profiles.yml" /root/.kcli/profiles.yml

    #sudo -E ./freeipa-server-container/configure-kcli-profile.sh || { log "Failed to configure freeipa-server-container"; exit 1; }
    sudo -E ./openshift-jumpbox/configure-kcli-profile.sh || { log "Failed to configure openshift-jumpbox"; exit 1; }
    sudo -E ./ansible-aap/configure-kcli-profile.sh || { log "Failed to configure ansible-aap"; exit 1; }
    sudo -E ./device-edge-workshops/configure-kcli-profile.sh || { log "Failed to configure device-edge-workshops"; exit 1; }
    sudo -E ./microshift-demos/configure-kcli-profile.sh || { log "Failed to configure microshift-demos"; exit 1; }
    sudo -E ./kubernetes/configure-kcli-profile.sh || { log "Failed to configure kubernetes"; exit 1; }
    sudo -E ./jupyterlab/configure-kcli-profile.sh || { log "Failed to configure jupyterlab"; exit 1; }
    sudo -E ./ceph-cluster/configure-kcli-profile.sh || { log "Failed to configure ceph-cluster"; exit 1; }
    sudo -E ./rhel9-pxe/configure-kcli-profile.sh || { log "Failed to configure rhel9-pxe"; exit 1; }
    sudo -E ./step-ca-server/configure-kcli-profile.sh || { log "Failed to configure step-ca-server"; exit 1; }
    sudo -E ./ubuntu/configure-kcli-profile.sh || { log "Failed to configure ubuntu"; exit 1; }
    echo $CUSTOM_PROFILE || exit 1
    if [[ "$CUSTOM_PROFILE"  == "true" ]] && [ ${VM_PROFILE} != "freeipa" ]; then
        log "Configuring ${VM_PROFILE} type"
        sudo -E /opt/kcli-pipelines/${VM_PROFILE}/configure-kcli-profile.sh || { log "Failed to configure ${VM_PROFILE}"; exit 1; }
    fi

    sudo cat ~/.kcli/profiles.yml | sudo tee /tmp/kcli-profiles.yml > /dev/null

    if [ "$USER" != "root" ]; then
        sudo cp kcli-profiles.yml "/home/$KCLI_USER/.kcli/profiles.yml"
        sudo cp kcli-profiles.yml "/home/$USER/.kcli/profiles.yml"
    fi
    sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
}


# This script checks if the VM_PROFILE environment variable is set.
# If VM_PROFILE is not set, it logs an error message and exits with status code 1.
# This script configures KCLI profiles by performing the following steps:
# 1. Clones or pulls the latest version of the repository.
# 2. Configures the environment settings required for KCLI.
# 3. Generates the necessary profiles for KCLI.
# 4. Configures the KCLI profiles based on the generated profiles.
# 5. Logs a message indicating that the script has completed successfully.
main() {
    clone_or_pull_repo
    configure_environment
    generate_profiles
    configure_kcli_profiles
    log "Script completed successfully"
}

main
