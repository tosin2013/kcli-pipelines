#!/bin/bash 
if [ -z "$VM_NAME" ];
then 
    echo "Please provide the name of the VM to deploy"
    exit 1
fi

echo "Deploying VM $VM_NAME"