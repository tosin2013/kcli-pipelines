#!/bin/bash 
#set -e

if [ $# -ne 3  ]; then 
    echo "No arguments provided"
    echo "Usage: $0 <rhel_username> <rhel_password> <provided_sha_value>"
    exit 1
fi

sudo subscription-manager refresh
sudo subscription-manager attach --auto
sudo dnf update -y 
sudo dnf install git vim unzip wget bind-utils tar ansible-core python3 python3-pip util-linux-user -y 
sudo dnf install ncurses-devel curl -y
curl 'https://vim-bootstrap.com/generate.vim' --data 'editor=vim&langs=javascript&langs=go&langs=html&langs=ruby&langs=python' > ~/.vimrc


if [ -d /opt/agnosticd/ansible ]; then
    sudo rm -rf /opt/agnosticd
fi
cd /opt/
git clone https://github.com/redhat-cop/agnosticd.git
cd /opt/agnosticd/ansible
git checkout development

cat >hosts<<EOF
localhost   ansible_connection=local
EOF

cat >run_me.yaml<<EOF
- name: Install Ansible automation controller
  hosts: localhost
  gather_facts: false
  become: true

  tasks:
    - name: Install Ansible automation controller
      include_role:
        name: aap_download                     
EOF

cp /root/.vault_password /opt/agnosticd/ansible/


offline_token=$(cat /root/offline_token)
export PROVIDED_SHA_VALUE="$3"
# https://access.redhat.com/downloads/content/480/ver=2.3/rhel---9/2.3/x86_64/product-software
cat >dev.yml<<EOF
---
offline_token: '$(cat /root/offline_token)'
provided_sha_value: ${PROVIDED_SHA_VALUE}
EOF

ansible-playbook -i hosts run_me.yaml --extra-vars @dev.yml -vv || exit $?

tar -zxvf aap.tar.gz 
cd ansible-automation-platform-setup-bundle-*/

export REGISTRY_USERNAME="$1"
export REGISTRY_PASSWORD="$2"

VM_IP_ADDRESS=$(hostname -I | awk '{print $1}')

cat >inventory<<EOF
[automationcontroller]
edge-manager-local.local ansible_connection=local

[database]

[all:vars]
admin_password='CHANGEME'

pg_host=''
pg_port=''

pg_database='awx'
pg_username='awx'
pg_password='CHANGEME'
pg_sslmode='prefer'  # set to 'verify-full' for client-side enforced SSL

registry_url='registry.redhat.io'
registry_username='${REGISTRY_USERNAME}'
registry_password='${REGISTRY_PASSWORD}'

nginx_http_port='10080'
nginx_https_port='10443'
EOF

sudo ./setup.sh 

echo "https://$VM_IP_ADDRESS" > /opt/aap_info.txt
echo "Username: admin" | tee -a /opt/aap_info.txt
echo "Password: $(cat inventory | grep admin_password | awk -F"'" '{print $2}')" | tee -a /opt/aap_info.txt

cat /opt/aap_info.txt