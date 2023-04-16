#!/bin/bash 
set -e 
if [ -z "$VM_NAME" ];
then 
    echo "Please provide the name of the VM to deploy"
    exit 1
fi

echo "Deploying VM $VM_NAME"
VM_INSTANCE=$VM_NAME-$(echo $RANDOM | md5sum | head -c 5; echo;)
kcli create vm -p $VM_NAME ${VM_INSTANCE} --wait
#kcli delete vm $VM_NAME -y