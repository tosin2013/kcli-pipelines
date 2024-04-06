## !/bin/bash
## https://ypbind.de/maus/notes/real_life_step-ca_with_multiple_users/
set -x

if [ -z "$DOMAIN" ]; then
    echo "DOMAIN is not set"
    read -p "Enter the domain name: " DOMAIN
else
    echo "DOMAIN is set to $DOMAIN"
    DOMAIN=${DOMAIN:-example.com}
fi


cd /tmp/ && curl -OL https://raw.githubusercontent.com/tosin2013/openshift-4-deployment-notes/master/pre-steps/configure-openshift-packages.sh
chmod +x /tmp/configure-openshift-packages.sh && /tmp/configure-openshift-packages.sh -i
wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.rpm && sudo rpm -i step-cli_amd64.rpm
wget https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.rpm && sudo rpm -i step-ca_amd64.rpm
ansible-galaxy collection install maxhoesel.smallstep>=0.25.2
sudo hostnamectl set-hostname step-ca.${DOMAIN}

if [ -f /tmp/initial_password ]; then
    mkdir -p /etc/step
    cp /tmp/initial_password /etc/step/initial_password
fi

if [ ! -f /etc/step/initial_password ]; then
    mkdir -p /etc/step
    # Collect password from user
    echo -n "Enter a password for the root provisioner: "
    read -s password
    echo "$password" > /etc/step/initial_password
fi

step ca init  --dns=step-ca.${DOMAIN} --address='[::]:443'  \
    --address=0.0.0.0:443  --name="Certificate authority for internal.${DOMAIN}" \
    --deployment-type=standalone --provisioner="root@internal.${DOMAIN} " --password-file=/etc/step/initial_password

step ca provisioner add acme --type ACME

jq '.authority.provisioners[0].claims = {
    "minTLSCertDuration": "5m",
    "maxTLSCertDuration": "2000h",
    "defaultTLSCertDuration": "2000h"
}' .step/config/ca.json > .step/config/ca.json.tmp && mv .step/config/ca.json.tmp .step/config/ca.json

nohup step-ca $(step path)/config/ca.json --password-file=/etc/step/initial_password > step-ca.log 2>&1 &
cat step-ca.log
echo "step-ca $(step path)/config/ca.json"
