#!/bin/bash
set -euo pipefail
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

# Function to get OS and version
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

# Function to determine the command based on the OS and version
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

# Function to clone or pull the git repo
clone_or_pull_repo() {
    GIT_REPO=https://github.com/tosin2013/kcli-pipelines.git

    if [ -z "$TARGET_SERVER" ]; then
        log "TARGET_SERVER variable is not set"
        exit 1
    fi

    if [ ! -d "/home/github_runner/kcli-pipelines" ]; then
        sudo git clone "$GIT_REPO" "/home/github_runner/kcli-pipelines" || { log "Failed to clone repo"; exit 1; }
    else
        cd "/home/github_runner/kcli-pipelines"
        sudo git pull || { log "Failed to pull repo"; exit 1; }
    fi
}

# Function to configure the environment
configure_environment() {
    if [ "$TARGET_SERVER" == "rhel8-equinix" ] || [ "$TARGET_SERVER" == "rhel9-equinix" ]; then
        sudo sed -i 's/NET_NAME=qubinet/NET_NAME=default/g' "/home/github_runner/kcli-pipelines/helper_scripts/default.env"
    fi

    if [ "$VM_PROFILE" == "kcli-openshift4-baremetal" ]; then
        sudo sed -i 's/NET_NAME=.*/NET_NAME=lab-baremetal/g' "/home/github_runner/kcli-pipelines/helper_scripts/default.env"
    fi

    if [ ! -f ~/.ssh/id_rsa ]; then
        log "SSH key does not exist"
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "kcli-pipelines@${HOSTNAME}"
    else
        eval $(ssh-agent)
        ssh-add ~/.ssh/id_rsa
    fi

    if [ ! -f "/home/github_runner/kcli-pipelines/ansible.cfg" ]; then
        cat >"/home/github_runner/kcli-pipelines/ansible.cfg" <<EOF
[defaults]
remote_tmp = /tmp/ansible-$USER
EOF
    fi

    source "${HOME}/kcli-pipelines/helper_scripts/helper_functions.sh"
}

# Function to generate profiles
generate_profiles() {
    cd "${HOME}/kcli-pipelines"
    
    sudo sed -i "s|export INVENTORY=localhost|export INVENTORY='${TARGET_SERVER}'|g" helper_scripts/default.env
    sudo sed -i "s|KCLI_SAMPLES_DIR=.*|KCLI_SAMPLES_DIR="/home/${USER}/kcli-pipelines/"|g" helper_scripts/default.env
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

# Function to configure kcli profiles
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

    if [ ! -f "${HOME}/kcli-pipelines/kcli-profiles.yml" ]; then
        log "kcli-profiles.yml file does not exist"
        exit 1
    fi

    sudo cp "/home/github_runner/kcli-pipelines/kcli-profiles.yml" "/home/$KCLI_USER/.kcli/profiles.yml"
    sudo cp "/home/github_runner/kcli-pipelines/kcli-profiles.yml" "/home/$USER/.kcli/profiles.yml"
    sudo cp "/home/github_runner/kcli-pipelines/kcli-profiles.yml" /root/.kcli/profiles.yml

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
    if [[ "$CUSTOM_PROFILE"  == "true" ]]; then
        log "Configuring ${VM_PROFILE} type"
        sudo -E /home/github_runner/kcli-pipelines/${VM_PROFILE}/configure-kcli-profile.sh || { log "Failed to configure ${VM_PROFILE}"; exit 1; }
    fi

    cat ~/.kcli/profiles.yml | tee /tmp/kcli-profiles.yml > /dev/null

    if [ "$USER" != "root" ]; then
        sudo cp kcli-profiles.yml "/home/$KCLI_USER/.kcli/profiles.yml"
        sudo cp kcli-profiles.yml "/home/$USER/.kcli/profiles.yml"
    fi
    sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
}

# Main function to orchestrate the script
# Ensure VM_PROFILE is set
if [ -z "$VM_PROFILE" ]; then
    log "VM_PROFILE variable is not set"
    exit 1
fi

# Ensure VM_PROFILE is set
if [ -z "$VM_PROFILE" ]; then
    log "VM_PROFILE variable is not set"
    exit 1
fi

main() {
    clone_or_pull_repo
    configure_environment
    generate_profiles
    configure_kcli_profiles
    log "Script completed successfully"
}

main
