#!/bin/bash 
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe
if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ ! -d /opt/ocp4-disconnected-helper ];
then 
    cd /opt/
    git clone https://github.com/tosin2013/ocp4-disconnected-helper.git
    cd ocp4-disconnected-helper
else
    cd /opt/ocp4-disconnected-helper
    git config pull.rebase false
    git config --global --add safe.directory /opt/ocp4-disconnected-helper
    git pull
fi 

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi

# SETUP_HARBER_REGISTRY does not exist exit 
if [ -z "$SETUP_HARBER_REGISTRY" ];
then 
    echo "SETUP_HARBER_REGISTRY does not exist"
    exit 1
fi

# DOWNLOAD_TO_TAR does not exist exit
if [ -z "$DOWNLOAD_TO_TAR" ];
then 
    echo "DOWNLOAD_TO_TAR does not exist"
    exit 1
fi

# PUSH_TAR_TO_REGISTRY does not exist exit
if [ -z "$PUSH_TAR_TO_REGISTRY" ];
then 
    echo "PUSH_TAR_TO_REGISTRY does not exist"
    exit 1
fi

DOMAIN=$(yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
export VM_PROFILE=harbor
export VM_NAME="harbor"
export  ACTION="create" # create, delete

/opt/kcli-pipelines/deploy-vm.sh
IP_ADDRESS=$(${USE_SUDO} /usr/bin/kcli info vm harbor | grep ip: | awk '{print $2}')

${USE_SUDO} sshpass -p "$SSH_PASSWORD" ${USE_SUDO} ssh-copy-id -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no cloud-user@${IP_ADDRESS} || exit $?

cd  /opt/ocp4-disconnected-helper
${USE_SUDO}  tee /tmp/inventory <<EOF
## Ansible Inventory template file used by Terraform to create an ./inventory file populated with the nodes it created

[harbor]
${VM_NAME}.${DOMAIN}

[all:vars]
ansible_ssh_private_key_file=/root/.ssh/id_rsa
ansible_ssh_user=cloud-user
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_internal_private_ip=${IP_ADDRESS}
EOF

${USE_SUDO} cat /tmp/inventory

# Create the CA key
${USE_SUDO} openssl genrsa -out ca.key 4096

# Generate a self-signed CA certificate
${USE_SUDO} openssl req -x509 -new -nodes -sha512 -days 3650 \
 -subj "/C=US/ST=Tennessee/L=Nashville/O=ContainersRUs/OU=InfoSec/CN=RootCA" \
 -key ca.key \
 -out ca.crt

# Add the Root CA to your system trust
${USE_SUDO} cp ca.crt /etc/pki/ca-trust/source/anchors/harbor-ca.pem
${USE_SUDO} update-ca-trust

# You'll also need to add that CA Cert to whatever system you're accessing Harbor with

# Generate a Server Certificate Key
${USE_SUDO} openssl genrsa -out harbor.${DOMAIN}.key 4096

# Generate a Server Certificate Signing Request
${USE_SUDO} openssl req -sha512 -new \
    -subj "/C=US/ST=Gerogia/L=Atlanta/O=ContainersRUs/OU=DevOps/CN=harbor.${DOMAIN}" \
    -key harbor.${DOMAIN}.key \
    -out harbor.${DOMAIN}.csr

# Create an x509 v3 Extension file
${USE_SUDO} cat > openssl-v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=harbor.${DOMAIN}
DNS.2=harbor
EOF

# Sign the Server Certificate with the CA Certificate
${USE_SUDO} openssl x509 -req -sha512 -days 730 \
    -extfile openssl-v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in harbor.${DOMAIN}.csr \
    -out harbor.${DOMAIN}.crt

# Bundle the Server Certificate and the CA Certificate
${USE_SUDO} cat harbor.${DOMAIN}.crt ca.crt > harbor.${DOMAIN}.bundle.crt

# Convert YAML to JSON
yq eval -o=json '.' extra_vars/setup-harbor-registry-vars.yml  > output.json

# Load the certificate contents into a shell variable
certificate=$(cat harbor.rtodgpoc.com.bundle.crt)
certificate_key=$(cat harbor.rtodgpoc.com.key)

# Use jq to update the ssl_certificate field with the certificate
jq --arg cert "$certificate" '.ssl_certificate = $cert' output.json > /tmp/1.json
jq --arg cert "$certificate_key" '.ssl_certificate_key = $cert' /tmp/1.json > test_new.json

# Convert JSON back to YAML
yq eval --output-format=yaml '.' test_new.json > output.yaml
yq eval '.harbor_hostname = "harbor.'${DOMAIN}'"' -i output.yaml || exit $?

# if SETUP_HARBER_REGISTRY is set to true, then run the playbook
if [ "${SETUP_HARBER_REGISTRY}" == "true" ];
then 
    /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/setup-harbor-registry.yml  -e "@output.yaml" -vv || exit $?
fi

# if DOWNLOAD_TO_TAR is set to true, then run the playbook
if [ "${DOWNLOAD_TO_TAR}" == "true" ];
then 
    /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/download-to-tar.yml  -e "@extra_vars/download-to-tar-vars.yml" -vv || exit $?
fi

#if PUSH_TAR_TO_REGISTRY is set to true, then run the playbook
if [ "${PUSH_TAR_TO_REGISTRY}" == "true" ];
then 
    /usr/local/bin/ansible-playbook -i /tmp/inventory /opt/ocp4-disconnected-helper/playbooks/push-tar-to-registry.yml  -e "@extra_vars/push-tar-to-registry-vars.yml" -vv || exit $?
fi
