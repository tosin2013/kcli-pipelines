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
    sudo kcli create vm -p $VM_NAME $VM_NAME --wait
elif [ $ACTION == "delete" ];
then 
    TARGET_VM=$(kcli list vm  | grep  ${VM_NAME} | awk '{print $2}')
    echo "Deleting VM $TARGET_VM"
    kcli delete vm $TARGET_VM -y
fi