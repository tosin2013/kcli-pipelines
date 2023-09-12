#!/bin/bash
#set -xe

GIT_REPO=https://github.com/tosin2013/kcli-pipelines.git

if [ ! -d /opt/kcli-pipelines ];
then 
    sudo git clone $GIT_REPO /opt/kcli-pipelines || exit $?
else 
    cd /opt/kcli-pipelines
    sudo git pull
fi

if [ $TARGET_SERVER == "equinix" ];
then 
    source ~/.bash_aliases
    source ~/.profile
    sudo  ln -s /root/.local/bin/ansible-vault /usr/bin/ansible-vault
    whereis ansible-vault
    sudo ansible-vault --help
    sudo sed -i 's/NET_NAME=qubinet/NET_NAME=default/g' /opt/kcli-pipelines/helper_scripts/default.env
fi

cd /opt/kcli-pipelines
sudo sed -i 's|export INVENTORY=localhost|export INVENTORY="'${TARGET_SERVER}'"|g' helper_scripts/default.env
source helper_scripts/default.env 
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
echo "KCLI USER: $KCLI_USER" || exit $?
rm -rf ~/.kcli/profiles.yml
rm -f /root/.kcli/profiles.yml
sudo python3 profile_generator/profile_generator.py update-yaml rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
sudo python3 profile_generator/profile_generator.py update-yaml fedora37 fedora37/template.yaml --vars-file fedora37/vm_vars.yaml


sudo -E ./freeipa-server-container/configure-kcli-profile.sh
#echo "*********************************************"
#cat ~/.kcli/profiles.yml
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
cat ~/.kcli/profiles.yml
echo "*********************************************"
#read -n 1 -s -r -p "Press any key to continue"
sleep 15s
if [ $KCLI_USER != "root" ];
then 
    sudo cp kcli-profiles.yml /home/$KCLI_USER/.kcli/profiles.yml
fi
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
