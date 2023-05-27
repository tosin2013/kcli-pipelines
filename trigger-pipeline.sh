#!/bin/bash 
# systemd-resolve --status
TOKEN="GITLAB-TOKEN"
SSH_PASSWORD="MACHINE_PASSWORD"
TARGET_SERVER=equinix
SSH_HOST="192.168.1.25"
SSH_USER="lab-user"
ACTION=create #delete

read -p "Would you like to run the configure-vm-profiles? (y/n): " decision
if [[ $decision == "y" || $decision == "Y" ]]; then
   python3 trigger-gitlab-pipeline.py --project_id=9 --token=$TOKEN --ref=main --ssh_password="${SSH_PASSWORD}" \
      --ssh_host=$SSH_HOST --job_type=configure-vm-profiles --target_server=$TARGET_SERVER --ssh-user=$SSH_USER
else
    echo "Skipping configure-vm-profiles"
fi

# Define the array
my_array=(
"freeipa-server-container"
"openshift-jumpbox"
"device-edge-workshops"
"mirror-registry"
"microshift-demos"
)

# Prompt the user to select an option
echo "Please select one of the following options:"
for ((i=0; i<${#my_array[@]}; i++))
do
  echo "$((i+1)). ${my_array[i]}"
done

# Read user input
read -p "Enter your choice (1-${#my_array[@]}): " choice

# Validate user input
# Validate user input
if [[ $choice =~ ^[1-5]$ ]]; then
  index=$((choice-1))
  selected_option="${my_array[index]}"
  echo "You selected: $selected_option"
  read -p "Would you like to create (c) or delete (d)  $selected_option? (c/d): " decision
  if [[ $decision == "c" || $decision == "C" ]]; then
    python3 trigger-gitlab-pipeline.py --project_id=9 --token=$TOKEN --ref=main --ssh_password="${SSH_PASSWORD}" \
      --ssh_host=$SSH_HOST --job_type=deploy-vm --target_server=$TARGET_SERVER --vm_name=$selected_option --action=create    --ssh-user=$SSH_USER
  elif [[ $decision == "d" || $decision == "D" ]]; then
    python3 trigger-gitlab-pipeline.py --project_id=9 --token=$TOKEN --ref=main --ssh_password="${SSH_PASSWORD}" \
      --ssh_host=$SSH_HOST --job_type=deploy-vm --target_server=$TARGET_SERVER --vm_name=$selected_option --action=delete    --ssh-user=$SSH_USER
  else
    echo "Invalid choice. Please try again."
  fi
else
  echo "Invalid choice. Please try again."
fi
