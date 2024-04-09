#!/bin/bash
# https://github.com/quay/mirror-registry
# Usage: ./configure-quay.sh <version> <domain> #v1.3.10

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <domain>"
    exit 1
fi

VERSION=${1}
DOMAIN=${2}

sudo dnf update -y
sudo dnf install curl wget tar jq skopeo httpd-tools openssl nano nfs-utils bash-completion bind-utils ansible-core vim libvirt firewalld acl policycoreutils-python-utils -y
sudo dnf install podman podman-docker podman-compose -y || exit $?
if ! grep -q "0" /proc/sys/net/ipv4/ip_unprivileged_port_start; then
    sudo tee "/proc/sys/net/ipv4/ip_unprivileged_port_start" <<< "0"
fi

if [  ! -f $HOME/mirror-registry-offline.tar.gz ];
then
    cd $HOME
    curl -OL "https://github.com/quay/mirror-registry/releases/download/${VERSION}/mirror-registry-offline.tar.gz"
    tar -zxvf mirror-registry-offline.tar.gz
fi 
sudo mkdir -p /registry/
sudo chmod -R 775 /registry/
sudo chown cloud-user:cloud-user  -R  /registry/
sudo choown cloud-user:cloud-user  -R /home/cloud-user 


if [ ! -s "/root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt" ]; then
    echo "Installing mirror-registry without self-signed certificate"
    ./mirror-registry install  --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN} -vv || tee /tmp/mirror-registry-offline.log 
fi

if [ ! -s "/root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt" ]; then
    echo "Installing mirror-registry without self-signed certificate"
    ./mirror-registry install  --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN} --certPath mirror-registry.${DOMAIN}.crt --sslKey /home/${USER}/mirror-registry.${DOMAIN}.key || tee /tmp/mirror-registry-offline.log
fi
