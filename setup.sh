#!/bin/bash

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


python3 profile_generator/profile_generator.py update-yaml rhel9 rhel9/template.yaml --vars-file rhel9/vm_vars.yml
python3 profile_generator/profile_generator.py update-yaml fedora37 fedora37/template.yaml --vars-file fedora37/vm_vars.yaml