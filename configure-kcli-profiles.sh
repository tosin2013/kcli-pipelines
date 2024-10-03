#!/bin/bash
#set -x
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
GIT_REPO=https://github.com/tosin2013/kcli-pipelines.git

if [ -z $TARGET_SERVER ];
then 
    echo "TARGET_SERVER variable is not set"
    exit 1
fi

if [ ! -d ${HOME}/kcli-pipelines ];
then 
    sudo git clone $GIT_REPO ${HOME}/kcli-pipelines || exit $?
else 
    cd ${HOME}/kcli-pipelines
    sudo git pull
fi

if [ $TARGET_SERVER == "rhel8-equinix" ] || [ $TARGET_SERVER == "rhel9-equinix" ];
then 
    sudo sed -i 's/NET_NAME=qubinet/NET_NAME=default/g' ${HOME}/kcli-pipelines/helper_scripts/default.env
fi

if [ $VM_PROFILE == "kcli-openshift4-baremetal" ];
then 
    sudo sed -i 's/NET_NAME=.*/NET_NAME=lab-baremetal/g' ${HOME}/kcli-pipelines/helper_scripts/default.env
fi

if [ ! -f  ~/.ssh/id_rsa ];
then
    echo "SSH key does not exist"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "kcli-pipelines@${HOSTNAME}"
else
    eval $(ssh-agent)
    ssh-add ~/.ssh/id_rsa
fi


if [ ! -f ${HOME}/kcli-pipelines/ansible.cfg ];
then
   cat >${HOME}/kcli-pipelines/ansible.cfg<<EOF
[defaults]
remote_tmp = /tmp/ansible-$USER
EOF
fi

source ${HOME}/helper_scripts/helper_functions.sh

cd ${HOME}/kcli-pipelines
sudo sed -i 's|export INVENTORY=localhost|export INVENTORY="'${TARGET_SERVER}'"|g' helper_scripts/default.env
source helper_scripts/default.env 
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
echo "KCLI USER: $KCLI_USER" || exit $?
rm -rf ~/.kcli/profiles.yml
sudo rm -f /root/.kcli/profiles.yml
determine_command_yaml
sudo python3 profile_generator/profile_generator.py $COMMAND rhel8 rhel8/template.yaml --vars-file rhel8/vm_vars.yml
sudo python3 profile_generator/profile_generator.py $COMMAND rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
sudo python3 profile_generator/profile_generator.py $COMMAND fedora39 fedora39/template.yaml --vars-file fedora39/vm_vars.yaml
sudo python3 profile_generator/profile_generator.py $COMMAND centos9stream   centos9stream/template.yaml --vars-file centos9stream/vm_vars.yaml

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

if [ ! -f ${HOME}/kcli-pipelines/kcli-profiles.yml ];
then
    echo "kcli-profiles.yml file does not exist"
    exit 1
fi

cp ${HOME}/kcli-pipelines/kcli-profiles.yml /home/$KCLI_USER/.kcli/profiles.yml
cp ${HOME}/kcli-pipelines/kcli-profiles.yml /root/.kcli/profiles.yml
#echo "*********************************************"
#cat ~/.kcli/profiles.yml
#echo "*********************************************"
#read -n 1 -s -r -p "Press any key to continue"

sudo -E ./freeipa-server-container/configure-kcli-profile.sh || exit $?
#echo "*********************************************"
#cat ~/.kcli/profiles.yml | tee /tmp/kcli-profiles.yml > /dev/null
#echo "*********************************************"
#read -n 1 -s -r -p "Press any key to continue"
echo "Configuring openshift-jumpbox type"
echo "*********************************************"
sudo -E ./openshift-jumpbox/configure-kcli-profile.sh || exit $?
echo "Configuring ansible-aap type"
echo "*********************************************"
sudo -E ./ansible-aap/configure-kcli-profile.sh || exit $?
echo "Configuring device-edge-workshops type"
echo "*********************************************"
sudo -E ./device-edge-workshops/configure-kcli-profile.sh || exit $?
echo "Configuring microshift-demos type"
echo "*********************************************"
sudo -E ./microshift-demos/configure-kcli-profile.sh  || exit $?
echo "Configuring kubernetes type"
echo "*********************************************"
sudo -E ./kubernetes/configure-kcli-profile.sh || exit $?
echo "Configuring jupyterlab type"
echo "*********************************************"
sudo -E ./jupyterlab/configure-kcli-profile.sh || exit $?
echo "Configuring ceph-cluster type"
echo "*********************************************"
sudo -E ./ceph-cluster/configure-kcli-profile.sh || exit $?
echo "Configuring rhel9-pxe type"
echo "*********************************************"
sudo -E ./rhel9-pxe/configure-kcli-profile.sh || exit $?
#echo "Configuring ollama-api type"
#echo "*********************************************"
#sudo -E ./ollama-api/configure-kcli-profile.sh || exit $?
echo "Configuring step-ca-server type"
echo "*********************************************"
sudo -E ./step-ca-server/configure-kcli-profile.sh || exit $?
echo "Configuring ubuntu type"
echo "*********************************************"
sudo -E ./ubuntu/configure-kcli-profile.sh || exit $?
if [[ ! -z "$CUSTOM_PROFILE" ]];
then 
    echo "Configuring ${VM_PROFILE} type"
    echo "*********************************************"
    sudo -E ./${VM_PROFILE}/configure-kcli-profile.sh || exit $?
fi
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
