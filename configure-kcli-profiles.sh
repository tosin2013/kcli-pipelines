#!/bin/bash
set -x

#GIT_REPO=https://gitlab.tosins-cloudlabs.com/tosin/kcli-pipelines.git
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
    source ~/.profile
    source ~/.bash_aliases
    sudo  ln -s /root/.local/bin/ansible-vault /usr/bin/ansible-vault
    whereis ansible-vault
    sudo ansible-vault --help
    sed -i 's/NET_NAME=qubinet/NET_NAME=default/g' /opt/kcli-pipelines/helper_scripts/default.env
fi

cd /opt/kcli-pipelines
source helper_scripts/default.env 
KCLI_USER=$(yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
echo "KCLI USER: $KCLI_USER" || exit $?

sudo sed -i 's|export INVENTORY=localhost|export INVENTORY="'${TARGET_SERVER}'"|g' helper_scripts/default.env
sudo python3 profile_generator/profile_generator.py update_yaml rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
sudo python3 profile_generator/profile_generator.py update_yaml fedora37 fedora37/template.yaml --vars-file fedora37/vm_vars.yaml

sudo -E ./openshift-jumpbox/configure-kcli-profile.sh
sudo -E ./freeipa-server-container/configure-kcli-profile.sh
sudo -E ./ansible-aap/configure-kcli-profile.sh
sudo -E ./device-edge-workshops/configure-kcli-profile.sh
sudo -E ./microshift-demos/configure-kcli-profile.sh
sudo -E ./ansible-aap/configure-kcli-profile.sh
if [ $KCLI_USER != "root" ];
then 
    sudo cp kcli-profiles.yml /home/$KCLI_USER/.kcli/profiles.yml
fi
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml