#!/bin/bash 
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -xe
# Check if user is root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root!"
    exit 1
fi

if ! yq -v  &> /dev/null
then
    VERSION=v4.30.6
    BINARY=yq_linux_amd64
    sudo wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O /usr/bin/yq &&\
    sudo chmod +x /usr/bin/yq
fi

if ! jq -v  &> /dev/null
then
    sudo dnf install -y jq
fi

ANSIBLE_AAP=ansible-aap
ANSIBLE_HUB=ansible-hub
POSTGRES=postgres

#sudo kcli info vm $ANSIBLE_AAP ${ANSIBLE_HUB} ${POSTGRES} | grep ip: | awk '{print $2}'
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
    for i in $ANSIBLE_AAP $ANSIBLE_HUB $POSTGRES
    do
        ssh-copy-id root@${i}
    done
fi

cd $HOME/rhel-fleet-management-configurator

sudo cat >inventory_dev.yml<<EOF
---
all:
  children:
    dev:
      hosts:
        ${ANSIBLE_AAP}
      vars:
        connection: local

    automationcontroller:
      hosts:
        ${ANSIBLE_AAP}:

    automationhub:
      hosts:
        ${ANSIBLE_HUB}:

    # can be automationhub if you do not have a specific server for this
    builder:
      hosts:
        ${ANSIBLE_HUB}:

    # only needed if installing AAP with automation, can be removed if you are not
    database:
      hosts:
        ${POSTGRES}:
  vars:
    env: dev
...
EOF


ansible -i  inventory_dev.yml all  -m setup 

yaml_file="vaults/dev.yml"
offline_token=$(yq eval '.offline_token' "$yaml_file")

# Execute curl command to get access token
response=$(curl -sS https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
  -d grant_type=refresh_token \
  -d client_id=rhsm-api \
  -d refresh_token="$offline_token")

# Parse access token from response
access_token=$(echo "$response" | jq -r '.access_token')

# Update YAML file with access token
yaml_file="vaults/dev.yml"
yaml_path="."token""
echo "Updating $yaml_file with access token..."
yq -i  ''$yaml_path'="'$access_token'"' "$yaml_file"

ansible-playbook -i inventory_dev.yml playbooks/install_aap.yml --ask-vault-pass  -vv 
ansible-playbook -i inventory_dev.yml -l dev playbooks/hub_config.yml --ask-vault-pass  -vv
ansible-playbook -i inventory_dev.yml -l dev playbooks/controller_config.yml --ask-vault-pass -vv
