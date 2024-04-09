#!/bin/bash
# https://github.com/quay/mirror-registry
# Usage: ./configure-quay.sh domain quay_version ca_url fingerprint

if [ $# -ne 4 ]; then
    echo "Usage: $0 <domain> <quay_version> <ca_url> <fingerprint>"
    exit 1
fi

DOMAIN=${1}
QUAY_VERSION=${2}
CA_URL=${3}
FINGERPRINT=${4}

sudo dnf update -y
sudo dnf install curl wget tar jq skopeo httpd-tools openssl nano nfs-utils bash-completion bind-utils ansible-core vim libvirt firewalld acl policycoreutils-python-utils -y
sudo dnf -y install \
  podman \
  skopeo \
  buildah 

#==============================================================================
# Non-root podman hacks
sudo chmod 4755 /usr/bin/newgidmap
sudo chmod 4755 /usr/bin/newuidmap

sudo dnf reinstall -yq shadow-utils

cat > /tmp/xdg_runtime_dir.sh <<EOF
export XDG_RUNTIME_DIR="\$HOME/.run/containers"
EOF

sudo mv /tmp/xdg_runtime_dir.sh /etc/profile.d/xdg_runtime_dir.sh
sudo chmod a+rx /etc/profile.d/xdg_runtime_dir.sh
sudo cp /etc/profile.d/xdg_runtime_dir.sh /etc/profile.d/xdg_runtime_dir.zsh


cat > /tmp/ping_group_range.conf <<EOF
net.ipv4.ping_group_range=0 2000000
EOF
sudo mv /tmp/ping_group_range.conf /etc/sysctl.d/ping_group_range.conf

sudo sysctl --system

if ! grep -q "0" /proc/sys/net/ipv4/ip_unprivileged_port_start; then
    sudo tee "/proc/sys/net/ipv4/ip_unprivileged_port_start" <<< "0"
fi


if ! command -v step >/dev/null 2>&1; then
    wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.rpm
    sudo rpm -i step-cli_amd64.rpm
fi

hostnamectl set-hostname mirror-registry.${DOMAIN}

if [ ! -f /root/.step/config/defaults.json ];
then 
    step ca bootstrap --ca-url ${CA_URL} --fingerprint ${FINGERPRINT} || exit $?
    step certificate install $(step path)/certs/root_ca.crt
fi

if [ ! -f /home/$USER/${DOMAIN}.crt ];
then
  TOKEN=$(step ca token  mirror-registry.${DOMAIN})
  step ca certificate --token $TOKEN --not-after=1440h   mirror-registry.${DOMAIN}  mirror-registry.${DOMAIN}.crt  mirror-registry.${DOMAIN}.key 
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


echo "Installing mirror-registry without self-signed certificate"
./mirror-registry install  --quayRoot /registry/ --quayHostname mirror-registry.${DOMAIN} --certPath mirror-registry.${DOMAIN}.crt --sslKey /home/${USER}/mirror-registry.${DOMAIN}.key || tee /tmp/mirror-registry-offline.log
