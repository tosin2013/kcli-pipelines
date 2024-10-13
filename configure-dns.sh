#!/bin/bash

export vm_name="freeipa"
export ip_address=$(sudo kcli info vm "$vm_name" "$vm_name" | grep ip: | awk '{print $2}' | head -1)
export interface_name="bond0" # "System eth0"
echo "VM $vm_name created with IP address $ip_address"
sudo nmcli connection modify  "${interface_name}"  ipv4.dns $ip_address,147.75.207.207
sudo nmcli connection reload
# list the dns information using nmcli 
sudo nmcli connection show "${interface_name}" | grep ipv4.dns
