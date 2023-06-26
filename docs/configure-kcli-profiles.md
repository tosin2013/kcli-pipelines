# Create KCLI profiles for multiple environments

## Description
This workflow creates KCLI profiles for multiple environments, including Equinix, OpenShift Jumpbox, Ansible AAP, Device Edge Workshops, Microshift Demos, Mirror Registry, JupyterLab, and Ubuntu.

## Steps:

1. Clone the kcli-pipelines repository to /opt/kcli-pipelines.
2. If the target server is Equinix, update the NET_NAME variable in helper_scripts/default.env to default.
3. Source the default.env file.
4. Get the KCLI user name from the ANSIBLE_ALL_VARIABLES variable.
5. Delete the profiles.yml file from the user's home directory and the root directory.
6. Use the profile_generator/profile_generator.py script to update the profiles.yml file for RHEL9 and Fedora37.
7. Run the configure-kcli-profile.sh script for each of the following environments:
    * FreeIPA Server Container
    * OpenShift Jumpbox
    * Ansible AAP
    * Device Edge Workshops
    * Microshift Demos
    * Mirror Registry
    * JupyterLab
    * Ubuntu
8. Copy the kcli-profiles.yml file to the user's home directory and the root directory.
Expected Output:

The output of the workflow should be a profiles.yml file in the user's home directory and the root directory. The profiles.yml file should contain KCLI profiles for the following environments:

  * Equinix
  * OpenShift Jumpbox
  * Ansible AAP
  * Device Edge Workshops
  * Microshift Demos
  * Mirror Registry
  * JupyterLab
  * Ubuntu


## Error Handling:

If the kcli-pipelines repository cannot be cloned, the workflow will fail. If the NET_NAME variable cannot be updated in helper_scripts/default.env, the workflow will fail. If the profiles.yml file cannot be deleted from the user's home directory or the root directory, the workflow will fail. If the configure-kcli-profile.sh script fails for any of the environments, the workflow will fail.

## Dependencies:

The following dependencies are required to run this workflow:

* Git
* Ansible
* KCLI

## Testing:

The workflow can be tested by running it on a machine with the required dependencies installed. The output of the workflow should be a profiles.yml file in the user's home directory and the root directory. The profiles.yml file should contain KCLI profiles for the following environments:

* OpenShift Jumpbox
* Ansible AAP
* Device Edge Workshops
* Microshift Demos
* Mirror Registry
* JupyterLab
* Ubuntu