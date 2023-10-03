#!/bin/bash
#set -x
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
GIT_REPO=https://github.com/tosin2013/kcli-pipelines.git

if [ -z $TARGET_SERVER ];
then 
    echo "TARGET_SERVER variable is not set"
    exit 1
fi

if [ ! -d /opt/kcli-pipelines ];
then 
    sudo git clone $GIT_REPO /opt/kcli-pipelines || exit $?
else 
    cd /opt/kcli-pipelines
    sudo git pull
fi

if [ $TARGET_SERVER == "rhel8-equinix" ];
then 
    sudo sed -i 's/NET_NAME=qubinet/NET_NAME=default/g' /opt/kcli-pipelines/helper_scripts/default.env
fi

if [ ! -f  ~/.ssh/id_rsa ];
then
    echo "SSH key does not exist"
    exit 1
else
    eval $(ssh-agent)
    ssh-add ~/.ssh/id_rsa
fi


if [ ! -f /opt/kcli-pipelines/ansible.cfg ];
then
   cat >/opt/kcli-pipelines/ansible.cfg<<EOF
[defaults]
remote_tmp = /tmp/ansible-$USER
EOF
fi

cd /opt/kcli-pipelines
sudo sed -i 's|export INVENTORY=localhost|export INVENTORY="'${TARGET_SERVER}'"|g' helper_scripts/default.env
source helper_scripts/default.env 
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
echo "KCLI USER: $KCLI_USER" || exit $?
rm -rf ~/.kcli/profiles.yml
sudo rm -f /root/.kcli/profiles.yml
sudo python3 profile_generator/profile_generator.py update-yaml rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
sudo python3 profile_generator/profile_generator.py update-yaml fedora38 fedora38/template.yaml --vars-file fedora38/vm_vars.yaml

if [ ! -d /home/$KCLI_USER/.kcli ];
then
    echo "/home/$KCLI_USER/.kcli directory does not exist"
    mkdir -p /home/$KCLI_USER/.kcli
fi

if [ ! -d /root/.kcli ];
then
    echo "/root/.kcli directory does not exist"
    sudo mkdir -p /root/.kcli
fi

if [ ! -f /opt/kcli-pipelines/kcli-profiles.yml ];
then
    echo "kcli-profiles.yml file does not exist"
    exit 1
fi

cp /opt/kcli-pipelines/kcli-profiles.yml /home/$KCLI_USER/.kcli/profiles.yml
cp /opt/kcli-pipelines/kcli-profiles.yml /root/.kcli/profiles.yml
#echo "*********************************************"
#cat ~/.kcli/profiles.yml
#echo "*********************************************"
#read -n 1 -s -r -p "Press any key to continue"

sudo -E ./freeipa-server-container/configure-kcli-profile.sh
#echo "*********************************************"
#cat ~/.kcli/profiles.yml | tee /tmp/kcli-profiles.yml > /dev/null
#echo "*********************************************"
#read -n 1 -s -r -p "Press any key to continue"
sudo -E ./openshift-jumpbox/configure-kcli-profile.sh
sudo -E ./ansible-aap/configure-kcli-profile.sh
sudo -E ./device-edge-workshops/configure-kcli-profile.sh
sudo -E ./microshift-demos/configure-kcli-profile.sh
sudo -E ./mirror-registry/configure-kcli-profile.sh
sudo -E ./jupyterlab/configure-kcli-profile.sh
sudo -E ./ubuntu/configure-kcli-profile.sh
echo "*********************************************"
cat ~/.kcli/profiles.yml | tee /tmp/kcli-profiles.yml > /dev/null
echo "*********************************************"
#read -n 1 -s -r -p "Press any key to continue"
#sleep 15s
if [ $KCLI_USER != "root" ];
then 
    sudo cp kcli-profiles.yml /home/$KCLI_USER/.kcli/profiles.yml
fi
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
