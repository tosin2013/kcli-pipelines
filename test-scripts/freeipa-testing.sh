#!/bin/bash 

if [ -f ../helper_scripts/default.env ];
then 
  source ../helper_scripts/default.env
elif [ -f helper_scripts/default.env  ];
then 
  source helper_scripts/default.env 
else
  echo "default.env file does not exist"
  exit 1
fi

ANSIBLE_PLAYBOOK="sudo -E /usr/local/bin/ansible-playbook"
export ANSIBLE_HOST_KEY_CHECKING=False

echo "TEST 1:"
export VM_NAME_ONE="rhel9-$(echo $RANDOM | md5sum | head -c 5; echo;)"
$ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME_ONE}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=192.168.122.10" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
    --extra-vars "action=present" -vvv || exit $?

echo "TEST 2:"
export VM_NAME_TWO="cephvm-$(echo $RANDOM | md5sum | head -c 5; echo;)"
$ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME_TWO}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=192.168.122.20" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
    --extra-vars "action=present" -vvv  || exit $?

echo "TEST 3:"
export VM_NAME_THREE="mirrorvm-$(echo $RANDOM | md5sum | head -c 5; echo;)"
$ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=192.168.122.30" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
    --extra-vars "action=present" -vvv  || exit $?


echo "TEST 4:"
$ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME_THREE}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=192.168.122.30" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
    --extra-vars "action=absent" -vvv || exit $?


echo "TEST 5:"
$ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME_TWO}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=192.168.122.20" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
    --extra-vars "action=absent" -vvv || exit $?

echo "TEST 5:"
$ANSIBLE_PLAYBOOK helper_scripts/add_ipa_entry.yaml \
    --vault-password-file "$HOME"/.vault_password \
    --extra-vars "@${ANSIBLE_VAULT_FILE}" \
    --extra-vars "@${ANSIBLE_ALL_VARIABLES}" \
    --extra-vars "key=${VM_NAME_ONE}" \
    --extra-vars "freeipa_server_fqdn=idm.${DOMAIN_NAME}" \
    --extra-vars "value=192.168.122.10" \
    --extra-vars "freeipa_server_domain=${DOMAIN_NAME}" \
    --extra-vars "action=absent" -vvv || exit $?