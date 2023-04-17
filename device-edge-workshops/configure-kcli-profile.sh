#!/bin/bash
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -xe
if [ -f ../helper_scripts/default.env ];
then 
  source ../helper_scripts/default.env
elif [ -f helper_scripts/default.env  ];
then 
  source helper_scripts/default.env 
else
  echo "default.env file does not exist"
  exit 1
fi

cd $KCLI_SAMPLES_DIR
if [ -f /tmp/manifest.zip ]; then
  echo "manifest.zip file already exists"
else
  echo "manifest.zip file does not exist"
  #exit 1
fi

function deploy_via_kcli(){

    source helper_scripts/default.env 
    ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
    PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
    RHSM_PASSWORD=$(yq eval '.rhsm_password' "${ANSIBLE_VAULT_FILE}")
    RHSM_USERNAME=$(yq eval '.rhsm_username' "${ANSIBLE_VAULT_FILE}")
    RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
    RHSM_ACTIVATION_KEY=$(yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
    OFFLINE_TOKEN=$(yq eval '.offline_token' "${ANSIBLE_VAULT_FILE}")
    PULL_SECRET=$(yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
    DOMAIN_NAME=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
    VM_NAME=device-edge-workshops
    IMAGE_NAME=rhel-baseos-9.1-x86_64-kvm.qcow2
    DISK_SIZE=200
    MEMORTY=32768
    CPU_NUM=8
    sudo rm -rf kcli-profiles.yml
    if [ -f ~/.kcli/profiles.yml ]; then
      sudo cp  ~/.kcli/profiles.yml kcli-profiles.yml
    else
        sudo mkdir -p ~/.kcli
        sudo mkdir -p /root/.kcli
    fi
    if [ -d $HOME/.generated/vmfiles ]; then
        echo "generated directory already exists"
    else
        sudo mkdir -p  $HOME/.generated/vmfiles
        sudo mkdir -p  /root/.generated/vmfiles
    fi
cat >/tmp/vm_vars.yaml<<EOF
image: ${IMAGE_NAME}
user: cloud-user
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: ${CPU_NUM}
memory: ${MEMORTY}
net_name: ${NET_NAME} 
reservedns: 1.1.1.1
offline_token: ${OFFLINE_TOKEN}
rhnorg: ${RHSM_ORG}
rhnactivationkey: ${RHSM_ACTIVATION_KEY} 
EOF

    sudo python3 profile_generator/profile_generator.py update_yaml device-edge-workshops device-edge-workshops/template.yaml   --vars-file /tmp/vm_vars.yaml
    sudo echo ${PULL_SECRET} | sudo tee pull-secret.json
    cat pull-secret.json
    cat  kcli-profiles.yml
    ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1
    sudo cp kcli-profiles.yml ~/.kcli/profiles.yml
    sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
    sudo cp $(pwd)/device-edge-workshops/local-inventory.yml $(pwd)/device-edge-workshops/local-inventory.yml.bak
    sudo sed -i "s/your-password/${PASSWORD}/g" $(pwd)/device-edge-workshops/local-inventory.yml
    sudo cp $(pwd)/device-edge-workshops/local-inventory.yml  ~/.generated/vmfiles
    sudo cp $(pwd)/device-edge-workshops/local-inventory.yml /root/.generated/vmfiles
    sudo rm -rf $(pwd)/device-edge-workshops/local-inventory.yml
    sudo cp $(pwd)/device-edge-workshops/local-inventory.yml.bak $(pwd)/device-edge-workshops/local-inventory.yml
    sudo cp $(pwd)/device-edge-workshops/extra_vars.yml $(pwd)/device-edge-workshops/extra_vars.yml.bak
    sudo sed -i "s/your-password/${RHSM_PASSWORD}/g" $(pwd)/device-edge-workshops/extra_vars.yml
    sudo sed -i "s/your-username/${RHSM_USERNAME}/g" $(pwd)/device-edge-workshops/extra_vars.yml
    sudo sed -i "s/your-token-here/${OFFLINE_TOKEN}/g" $(pwd)/device-edge-workshops/extra_vars.yml
    sudo sed -i "s/internallab.io/${DOMAIN_NAME}/g" $(pwd)/device-edge-workshops/extra_vars.yml
    #$(pwd)/device-edge-workshops/manifest-generator.sh /tmp/manifest.zip
    sudo cp $(pwd)/device-edge-workshops/extra_vars.yml  ~/.generated/vmfiles
    sudo cp $(pwd)/device-edge-workshops/extra_vars.yml /root/.generated/vmfiles
    sudo sed -i "s/DOMAIN=testingdomain.io/DOMAIN=${DOMAIN_NAME}/g" $(pwd)/device-edge-workshops/setup-demo-infra.sh
    sudo cp $(pwd)/device-edge-workshops/setup-demo-infra.sh  ~/.generated/vmfiles
    sudo cp $(pwd)/device-edge-workshops/setup-demo-infra.sh /root/.generated/vmfiles
    cat  $(pwd)/device-edge-workshops/extra_vars.yml 
    sudo cp  $(pwd)/device-edge-workshops/extra_vars.yml.bak $(pwd)/device-edge-workshops/extra_vars.yml
    #echo "Creating VM ${VM_NAME}"
    #sudo kcli create vm -p device-edge-workshops ${VM_NAME} --wait
}

function deploy_via_aws(){
    echo "deploying via aws"
    #export AWS_ACCESS_KEY_ID=AKIA6ABLAH1223VBD3W
    #export AWS_SECRET_ACCESS_KEY=zh6gFREbvblahblahblahfXIC5nZr51OgdKECaSIMBi9Kc
}

DEPLOYMENT_TYPE=kcli # aws

if [ $DEPLOYMENT_TYPE == "kcli" ];
then 
    deploy_via_kcli
else [ $DEPLOYMENT_TYPE == "aws" ];
    deploy_via_aws
fi

#cd /opt/freeipa-workshop-deployer/2_ansible_config/
#IP_ADDRESS=$(sudo kcli info vm device-edge-workshops | grep ip: | awk '{print $2}')
#echo "IP Address: ${IP_ADDRESS}"
#sudo python3  dynamic_dns.py --add controller "$IP_ADDRESS" 
#sudo python3 dynamic_dns.py --add 'cockpit' "$IP_ADDRESS" 
#sudo python3 dynamic_dns.py --add 'gitea' "$IP_ADDRESS"
#sudo python3 dynamic_dns.py --add 'edge-manager' "$IP_ADDRESS"
#cd ..
#./2_ansible_config/populate-hostnames.sh || exit 1
#cd $KCLI_SAMPLES_DIR

#echo "Current Ansible Release:
#--------------------------------
#Ansible Automation Platform 2.3 Setup Bundle
#Last modified: 2023-03-16 SHA-256 Checksum: eae31a1c45e057c3f5d2302c6cf497060a51baec73c86a7f95042d51e4150eb8
#URL: https://access.redhat.com/downloads/content/480/ver=2.3/rhel---9/2.3/x86_64/product-software"
#echo "--------------------------------"
#echo "sudo kcli ssh device-edge-workshops"
#echo "sudo su -"
