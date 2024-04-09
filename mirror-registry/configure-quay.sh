#!/bin/bash
# https://github.com/quay/mirror-registry
# Usage: ./configure-quay.sh <version> <domain> #v1.3.10

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <domain>"
    exit 1
fi

VERSION=${1}
DOMAIN=${2}

dnf update -y
dnf install curl wget tar jq skopeo httpd-tools podman openssl nano nfs-utils bash-completion bind-utils ansible-core vim libvirt firewalld acl policycoreutils-python-utils -y

if ! grep -q "0" /proc/sys/net/ipv4/ip_unprivileged_port_start; then
    echo 0 > "/proc/sys/net/ipv4/ip_unprivileged_port_start"
fi

if [  ! -f $HOME/mirror-registry-offline.tar.gz ];
then
    curl -OL "https://github.com/quay/mirror-registry/releases/download/${VERSION}/mirror-registry-offline.tar.gz"
    tar -zxvf mirror-registry-offline.tar.gz
fi 
mkdir -p /registry/
#systemctl start firewalld
#systemctl enable firewalld
#firewall-cmd --add-port=8443/tcp --permanent
#firewall-cmd --reload
#semanage port -a -t http_port_t -p tcp 8443
#semanage port -l | grep -w http_port_t

if [ ! -s "/root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt" ]; then
    echo "Installing mirror-registry without self-signed certificate"
    ./mirror-registry install  --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN} || tee /tmp/mirror-registry-offline.log
fi

if [ ! -s "/root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt" ]; then
    echo "Installing mirror-registry without self-signed certificate"
    ./mirror-registry install  --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN}
  --certPath mirror-registry.${DOMAIN}.crt --sslKey /home/${USER}/mirror-registry.${DOMAIN}.key || tee /tmp/mirror-registry-offline.log
fi
