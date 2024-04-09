#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <domain>"
    exit 1
fi

VERSION=${1}
DOMAIN=${2}

dnf update -y
dnf install curl wget tar jq podman skopeo httpd-tools openssl nano nfs-utils bash-completion bind-utils ansible vim libvirt firewalld acl policycoreutils-python-utils -y
echo 0 > /proc/sys/net/ipv4/ip_unprivileged_port_start


curl -OL "https://github.com/quay/mirror-registry/releases/download/${VERSION}/mirror-registry-offline.tar.gz"
tar -zxvf mirror-registry-offline.tar.gz
mkdir -p /registry/
sudo firewall-cmd --add-port=8443/tcp --permanent
sudo firewall-cmd --reload
sudo semanage port -a -t http_port_t -p tcp 8443
sudo semanage port -l | grep -w http_port_t

if [ ! -s "/root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt" ]; then
    echo "Installing mirror-registry without self-signed certificate"
    sudo ./mirror-registry install --quayHostname $(hostname) --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN}
 || tee /tmp/mirror-registry-offline.log
fi

if [ ! -s "/root/.generated/vmfiles/mirror-registry.${DOMAIN}.crt" ]; then
    echo "Installing mirror-registry without self-signed certificate"
    sudo ./mirror-registry install --quayHostname $(hostname) --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN}
  --certPath mirror-registry.${DOMAIN}.crt --sslKey /home/${USER}/mirror-registry.${DOMAIN}.key || tee /tmp/mirror-registry-offline.log
fi
