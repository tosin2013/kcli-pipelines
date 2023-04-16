#!/bin/bash 
if [ -z "$1" ];
then 
    echo "Please provide the name of the VM to deploy"
    exit 1
fi

echo "Deploying VM $1"