# Deploy VM Workflow

Script: `deploy-vm.sh`

## Description: 
This script creates a new VM, adds it to the IDM, and updates the DNS.

## Inputs:

* `VM_NAME:` The name of the VM to create.
* `ACTION:` The action to perform, which can be create, delete, or deploy_app.
* `VM_PROFILE:` The VM profile to use.
* `DNS_FORWARDER:` The DNS forwarder to use.

## Outputs:

* The IP address of the newly created VM.

## Steps:

* Check if the IDM is reachable.
* Create the VM.
* Add the VM to the IDM.
* Update the DNS.

## Dependencies:
  
* The `kcli` command-line tool.
* The `ansible` command-line tool.

## Workflow:

1. The script starts by checking if the IDM is reachable. If it is not, the script exits.
2. The script then creates the VM.
3. The script then adds the VM to the IDM.
4. The script then updates the DNS.

## Assumptions:

* The IDM is configured and running.
* The kcli and ansible command-line tools are installed.

## Risks:

* The VM may not be created successfully.
* The VM may not be added to the IDM successfully.
* The DNS may not be updated successfully.

## Mitigation Strategies:

The script includes error handling to catch any errors that may occur.
The script can be run multiple times to retry any failed operations.

## Testing:

The script can be tested by creating a new VM and verifying that it is added to the IDM and the DNS is updated correctly.

## Monitoring:

The status of the VM can be monitored using the kcli command-line tool.

## Rollback:

If the script fails, the VM can be deleted using the kcli command-line tool.
