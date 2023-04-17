#!/bin/bash
set -x
whoami 

#GIT_REPO=https://gitlab.tosins-cloudlabs.com/tosin/kcli-pipelines.git
GIT_REPO=https://github.com/tosin2013/kcli-pipelines.git
cat >vm_vars.yaml<<EOF
image: rhel-baseos-9.1-x86_64-kvm.qcow2 
user: admin
user_password: secret
disk_size: 30
numcpus: 4
memory: 8192
net_name: default
rhnorg: orgid
rhnactivationkey: activationkey
reservedns: 1.1.1.1
EOF


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
fi
echo "NOW EXIT!!!"
exit 0

cd /opt/kcli-pipelines
sudo sed -i 's|export INVENTORY=localhost|export INVENTORY="'${TARGET_SERVER}'"|g' helper_scripts/default.env
sudo python3 profile_generator/profile_generator.py update_yaml rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
sudo python3 profile_generator/profile_generator.py update_yaml fedora37 fedora37/template.yaml --vars-file fedora37/vm_vars.yaml

sudo -E ./openshift-jumpbox/configure-kcli-profile.sh
sudo -E ./ansible-aap/configure-kcli-profile.sh
sudo -E ./device-edge-workshops/configure-kcli-profile.sh
sudo -E ./microshift-demos/configure-kcli-profile.sh
sudo cp kcli-profiles.yml ~/.kcli/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml