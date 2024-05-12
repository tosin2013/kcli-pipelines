#!/bin/bash 

if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi


if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi

function create_livirt_networks(){
    array=( "1924" "1925" "1926" "1927"  "1928" )
    for i in "${array[@]}"
    do
        echo "$i"

        tmp=$(sudo virsh net-list | grep "$i" | awk '{ print $3}')
        if ([ "x$tmp" == "x" ] || [ "x$tmp" != "xyes" ])
        then
            echo "$i network does not exist creating it"
            # Try additional commands here...

            cat << EOF > /tmp/$i.xml
<network>
<name>$i</name>
<bridge name='virbr$(echo "${i:0-1}")' stp='on' delay='0'/>
<domain name='$i' localOnly='yes'/>
</network>
EOF

            sudo virsh net-define /tmp/$i.xml
            sudo virsh net-start $i
            sudo virsh net-autostart  $i
    else
            echo "$i network already exists"
        fi
    done
}

function create(){
    create_livirt_networks
    IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder  | sort -k1 -k2 | tail -1 | awk '{print $5}' | sed 's/\/24//g')
    # Vyos nightly builds 
    # https://github.com/vyos/vyos-rolling-nightly-builds/releases
    VYOS_VERSION=1.5-rolling-202404270018
    ISO_LOC=https://github.com/vyos/vyos-rolling-nightly-builds/releases/download/${VYOS_VERSION}/vyos-${VYOS_VERSION}-amd64.iso
    if [ ! -f $HOME/vyos-${VYOS_VERSION}-amd64.iso ];
    then
        cd $HOME
        curl -OL $ISO_LOC
    fi
    

    VM_NAME=vyos-router
    sudo mv $HOME/${VM_NAME}.qcow2 /var/lib/libvirt/images/
    sudo cp $HOME/vyos-${VYOS_VERSION}-amd64.iso $HOME/seed.iso
    sudo mv $HOME/seed.iso /var/lib/libvirt/images/seed.iso

    # generate qcow2 blank image $VM_NAME.qcow2
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/$VM_NAME.qcow2 20G

sudo virt-install -n ${VM_NAME} \
   --ram 4096 \
   --vcpus 2 \
   --cdrom /var/lib/libvirt/images/seed.iso \
   --os-variant debian10 \
   --network network=default,model=e1000e,mac=$(date +%s | md5sum | head -c 6 | sed -e 's/\([0-9A-Fa-f]\{2\}\)/\1:/g' -e 's/\(.*\):$/\1/' | sed -e 's/^/52:54:00:/') \
   --network network=1924,model=e1000e \
   --network network=1925,model=e1000e \
   --network network=1926,model=e1000e \
   --network network=1927,model=e1000e \
   --network network=1928,model=e1000e \
   --graphics vnc \
   --hvm \
   --virt-type kvm \
   --disk path=/var/lib/libvirt/images/$VM_NAME.qcow2,bus=virtio \
   --import \
   --noautoconsole
}

function destroy(){
    VM_NAME=vyos-router
    sudo virsh destroy ${VM_NAME}
    sudo virsh undefine ${VM_NAME}
    sudo rm -rf /var/lib/libvirt/images/$VM_NAME.qcow2
    sudo rm -rf /var/lib/libvirt/images/seed.iso
}

if [ $ACTION == "create" ];
then 
  create
elif [ $ACTION == "delete" ]; 
then 
  destroy
else 
  echo "help"
fi
