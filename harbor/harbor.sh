#!/bin/bash

#Harbor on Ubuntu 18.04
# https://gist.github.com/kacole2/95e83ac84fec950b1a70b0853d6594dc
# https://github.com/goharbor/harbor/releases # v2.10.1

if [ $# -ne 4 ]; then
    echo "Usage: $0 <domain> <harbor-version> <ca-url> <fingerprint>"
    exit 1
fi

DOMAIN=${1}
HARBORVERSION=${2}
CA_URL=${3}
FINGERPRINT=${4}

if [ -z $HARBORVERSION ]; then
    HARBORVERSION=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
fi

if ! command -v step >/dev/null 2>&1; then
  wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb
  sudo dpkg -i step-cli_amd64.deb
fi 

hostnamectl set-hostname harbor.${DOMAIN}

if [ ! -f /root/.step/config/defaults.json ];
then 
    step ca bootstrap --ca-url ${CA_URL} --fingerprint ${FINGERPRINT}
    step certificate install $(step path)/certs/root_ca.crt
fi

if [ ! -f $HOME/${DOMAIN}.crt ];
then
  TOKEN=$(step ca token  harbor.${DOMAIN})
  step ca certificate --token $TOKEN --not-after=1440h   harbor.${DOMAIN}  harbor.${DOMAIN}.crt  harbor.${DOMAIN}.key 
fi

IPorFQDN=$(hostname -f)
# Housekeeping
apt update -y
swapoff --all
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
ufw disable #Do Not Do This In Production
echo "Housekeeping done"

#Install Latest Stable Docker Release
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "insecure-registries" : ["$IPorFQDN:443","$IPorFQDN:80","0.0.0.0/0"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
groupadd docker
MAINUSER=$(logname)
usermod -aG docker $MAINUSER
systemctl daemon-reload
systemctl restart docker
echo "Docker Installation done"

#Install Latest Stable Docker Compose Release
COMPOSEVERSION=$(curl -s https://github.com/docker/compose/releases/latest/download 2>&1 | grep -Po [0-9]+\.[0-9]+\.[0-9]+)
curl -L "https://github.com/docker/compose/releases/download/$COMPOSEVERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
echo "Docker Compose Installation done"

#Install Latest Stable Harbor Release


if [ -f harbor-online-installer-$HARBORVERSION.tgz ]; then
    echo "Harbor $HARBORVERSION already exists"
    tar xvf harbor-online-installer-$HARBORVERSION.tgz || exit 1
else
    #curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep browser_download_url | grep online | cut -d '"' -f 4 | wget -qi -
    curl -OL https://github.com/goharbor/harbor/releases/download/$HARBORVERSION/harbor-online-installer-$HARBORVERSION.tgz
    tar xvf harbor-online-installer-$HARBORVERSION.tgz || exit 1
fi

cd harbor
cp harbor.yml.tmpl harbor.yml
sed -i "s/reg.mydomain.com/$IPorFQDN/g" harbor.yml
sed -i "s/# external_url:.*/external_url: $IPorFQDN/g" harbor.yml
sed -i "s|certificate: /your/certificate/path|certificate: $HOME/harbor.${DOMAIN}.crt|" harbor.yml
sed -i "s|private_key: /your/private/key/path|private_key: $HOME/harbor.${DOMAIN}.key|"  harbor.yml
cat harbor.yml
echo -e "Harbor Installation Complete \n\nPlease log out and log in or run the command 'newgrp docker' to use Docker without sudo\n\nLogin to your harbor instance:\n docker login -u admin -p Harbor12345 $IPorFQDN"