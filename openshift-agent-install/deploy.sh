#!/bin/bash 
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe
if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ ! -d /opt/ocp4-disconnected-helper ];
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


if command -v nmstate &>/dev/null; then
  echo "nmstate is installed"
else
  echo "nmstate is not installed"
  ${USE_SUDO} dnf install nmstate -y 
fi


${USE_SUDO} /usr/local/bin/ansible-galaxy install -r openshift-agent-install/collections/requirements.yml

# Assign arguments to variables
DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
# 98c4fd93ab54e1555a911d33c5bb9c1283905cf215d72038eb856f6efda1c6f1
GRAPH_DATA_IMAGE=$(yq eval '.graph_data_image' "${ANSIBLE_ALL_VARIABLES}")
new_graphDataImage="harbor.${DOMAIN}/oc-mirror/openshift/graph-image@sha256:98c4fd93ab54e1555a911d33c5bb9c1283905cf215d72038eb856f6efda1c6f1"

new_releases="harbor.${DOMAIN}/oc-mirror/openshift/release-images"

# File to be updated
updateservice_file="templates/updateservice.yml.j2"
file="example_vars/kcli-pipeline-vars.yaml"



# Use yq to update the graphDataImage and releases fields
yq e ".spec.graphDataImage = \"$new_graphDataImage\"" -i "$updateservice_file"
yq e ".spec.releases = \"$new_releases\"" -i "$updateservice_file"

# updating pipeline vars 
yq e ".base_domain = \"$DOMAIN\"" -i "$file"
yq e ".ssh_public_key_path = \"$new_value\"" -i "$file"
yq e ".control_plane_replicas = \"$new_graphDataImage\"" -i "$file"
yq e ".app_node_replicas = \"$new_releases\"" -i "$file"
DNS_FORWARDER=$(sudo kcli info vm freeipa | grep ip: | awk '{print $2}' | head -1)
sed -i "s|192.168.122.10|${DNS_FORWARDER}|g" "$file"
sed -i "s|kemo.labs|${DOMAIN}|g" "$file"