#!/bin/bash 
# https://github.com/jjaswanson4/device-edge-workshops/tree/main/provisioner#lab-setup

DOMAIN=testingdomain.io
# Set the value to "yes"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart the SSH service
systemctl restart sshd

cd /opt/device-edge-workshops/provisioner
mkdir -p  lab-prefix.${DOMAIN}
if [ ! -f lab-prefix.${DOMAIN}/ssh-key ];
then 
    ssh-keygen -t rsa -b 4096 -f lab-prefix.${DOMAIN}/ssh-key -N ''
fi
BUILDER_KEY=$(cat lab-prefix.${DOMAIN}/ssh-key.pub)
cd ..

cp ~/extra_vars.yml .
cp ~/local-inventory.yml .
sed -i "s|your-workshop-domain.lcl|${DOMAIN}|g" local-inventory.yml
sed -i "s|192.168.200.10|$(hostname -I | awk '{print $1}')|g" local-inventory.yml
sed -i "s|your-key-here|${BUILDER_KEY}|g" extra_vars.yml
cat extra_vars.yml | less
ansible-galaxy  install -r execution-environment/requirements.yml
#sed -i '16d' provisioner/workshop_vars/rhde_aw_120.yml
#cat provisioner/workshop_vars/rhde_aw_120.yml | grep groups
ansible-playbook  provisioner/provision_lab.yml -e @extra_vars.yml  -e ansible_python_interpreter=/usr/bin/python3  -i local-inventory.yml



#TASK [../roles/control_node : Post manifest file] ******************************************************************************************************************************************************************************************************************************
#fatal: [edge-manager-local]: FAILED! => {"access_control_expose_headers": "X-API-Request-Id", "allow": "GET, POST, DELETE, HEAD, OPTIONS", "changed": false, "connection": "close", "content_language": "en", "content_length": "75", "content_type": "application/json", "date": "Mon, 27 Mar 2023 18:43:40 GMT", "elapsed": 0, "json": {"error": "Invalid manifest: a subscription manifest zip file is required."}, "msg": "Status code was 400 and not [200]: HTTP Error 400: Bad Request", "redirected": false, "server": "nginx", "status": 400, "url": "https://192.168.122.201/api/v2/config/", "vary": "Accept, Accept-Language, Origin, Cookie", "x_api_node": "192.168.122.201", "x_api_product_name": "Red Hat Ansible Automation Platform", "x_api_product_version": "4.2.2", "x_api_request_id": "b31e9f092e994ccf9e83fb053d5906d1", "x_api_time": "0.332s", "x_api_total_time": "0.578s"}
