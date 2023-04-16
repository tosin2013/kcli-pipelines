#!/bin/bash
MACHINE_NAME=hypervisor.rxc4p.dynamic.opentlc.com
MACHINE_USER=lab-user
# Display a menu and get the user's choice
echo "Select a demo to build:"
echo "1. e2e-demo"
echo "2. edge-console-demo/images"
echo "3. hello-microshift-demo"
echo "4. ibaas-demo"
echo "5. ostree-demo"
read -p "Enter choice [1-5]: " choice

# Depending on the user's choice, set the DEMONAME variable
case $choice in
  1)
    DEMONAME="e2e-demo"
    ;;
  2)
    DEMONAME="edge-console-demo/images"
    ;;
  3)
    DEMONAME="hello-microshift-demo"
    ;;
  4)
    DEMONAME="ibaas-demo"
    ;;
  5)
    DEMONAME="ostree-demo"
    ;;
  *)
    echo "Invalid choice"
    exit 1
esac

# prompt user if they want to start a build
read -p "Would you like to start a build? (yes/no): " choice
case "$choice" in 
  yes|YES|y|Y ) 
    # get DEMONAME variable from user
    read -p "Enter DEMONAME: " DEMONAME

    # start build
    ./scripts/build $DEMONAME
    ;;
  no|NO|n|N )
    echo "Exiting script without building."
    ;;
  * ) 
    echo "Invalid input, exiting script."
    ;;
esac

echo "Copying $DEMONAME-installer.x86_64.iso to $MACHINE_NAME"
scp builds/$DEMONAME/$DEMONAME-installer.x86_64.iso $MACHINE_USER@$MACHINE_NAME:/tmp/

cat >hosts<<EOF
[client]
${MACHINE_NAME}   ansible_user=${MACHINE_USER}
EOF

# Set up arrays of adjectives and nouns
adjectives=("happy" "fuzzy" "brave" "silly" "goofy" "quirky" "sunny" "lucky" "jolly" "curious")
nouns=("penguin" "giraffe" "tiger" "elephant" "llama" "koala" "hippo" "rhino" "zebra" "octopus")

# Generate a random index for each array
adj_index=$(( RANDOM % ${#adjectives[@]} ))
noun_index=$(( RANDOM % ${#nouns[@]} ))

# Construct the computer name using the adjective and noun at the chosen indices
computer_name="${adjectives[$adj_index]}-${nouns[$noun_index]}"
sed "s|libvirt_iso_name:.*|libvirt_iso_name: $DEMONAME-installer.x86_64.iso|g" edge_vars.yml > edge_vars_use.yml
sed -i "s/libvirt_vm_name:.*/libvirt_vm_name: $computer_name/g" edge_vars_use.yml
cat edge_vars_use.yml
echo "Deploying $DEMONAME to $MACHINE_NAME as $computer_name"
sudo ansible-playbook  -i hosts playbooks.yml -t create_kvm_vm  --extra-vars "@edge_vars_use.yml"  --private-key ~/.ssh/cluster-key -K

ssh -o "IdentitiesOnly=yes" -i builds/$DEMONAME/id_demo microshift@192.168.122.227