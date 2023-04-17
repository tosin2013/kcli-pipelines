#!/bin/bash 
set -e 
if [ -z "$VM_NAME" ];
then 
    echo "Please provide the name of the VM to deploy"
    exit 1
fi

if [ $ACTION == "create" ];
then 
    echo "Creating VM $VM_NAME"
    kcli create vm -p $VM_NAME $VM_NAME --wait
elif [ $ACTION == "delete" ];
then 
    echo "Deleting VM $VM_NAME"
    kcli delete vm $VM_NAME -y
fi