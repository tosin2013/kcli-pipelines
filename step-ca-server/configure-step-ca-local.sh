## !/bin/bash
## https://ypbind.de/maus/notes/real_life_step-ca_with_multiple_users/
set -x

if [ $# -ne 2 ]; then
    echo "Please pass domain namd and dns ip address as argument"
    echo "Usage: $0 <domain> <dns_ip>"
    exit 1
fi

DOMAIN=$1
DNS_IP=$2

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

if ! command -v oc &> /dev/null; then
    echo "oc command not found. Installing OpenShift CLI..."
    # Add code here to install OpenShift CLI
    cd /tmp/ && curl -OL https://raw.githubusercontent.com/tosin2013/openshift-4-deployment-notes/master/pre-steps/configure-openshift-packages.sh
    chmod +x /tmp/configure-openshift-packages.sh && /tmp/configure-openshift-packages.sh -i
fi

wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.rpm && sudo rpm -i step-cli_amd64.rpm
wget https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.rpm && sudo rpm -i step-ca_amd64.rpm
ansible-galaxy collection install maxhoesel.smallstep>=0.25.2
sudo hostnamectl set-hostname step-ca-server.${DOMAIN}


step ca init  --dns=step-ca-server.${DOMAIN} --address='[::]:443'  \
    --address=0.0.0.0:443  --name="Certificate authority for internal.${DOMAIN}" \
    --deployment-type=standalone --provisioner="root@internal.${DOMAIN} " --password-file=/etc/step/initial_password || exit $?

step ca provisioner add acme --type ACME

jq '.authority.provisioners[0].claims = {
    "minTLSCertDuration": "5m",
    "maxTLSCertDuration": "2000h",
    "defaultTLSCertDuration": "2000h"
}' .step/config/ca.json > .step/config/ca.json.tmp 
mv .step/config/ca.json .step/config/ca.json.bak
mv .step/config/ca.json.tmp .step/config/ca.json

nohup step-ca $(step path)/config/ca.json --password-file=/etc/step/initial_password > step-ca.log 2>&1 &
# pkill step-ca
cat step-ca.log
echo "step-ca $(step path)/config/ca.json"

export interface_name="System eth0"
sudo nmcli connection modify  "${interface_name}"  ipv4.dns $DNS_IP,1.1.1.1
sudo nmcli connection down "${interface_name}" && sudo nmcli connection up "${interface_name}"
# list the dns information using nmcli 
sudo nmcli connection show "${interface_name}" | grep ipv4.dns
