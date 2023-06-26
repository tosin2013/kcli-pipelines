# kcli-pipelines

## Workflow Documents
* [Create KCLI profiles for multiple environments](docs/configure-kcli-profiles.md)
* [Deploy VM Workflow](docs/deploy-vm.md)

## How to deploy Vms
* [Deploy the freeipa-server-container on vm](docs/deploy-dns.md)
* [Deploy the mirror-registry on vm](docs/mirror-registry.md)
* [Deploy the microshift-demos on vm](docs/microshift-demos.md)
* [Deploy thedevice-edge-workshops on vm](docs/device-edge-workshops.md)
* [Deploy the openshift-jumpbox on vm](docs/openshift-jumpbox.md)
* [Deploy the Red Hat Ansible Automation Platform on vm](docs/ansible-aap.md)
* [Deploy the ubuntu on vm](docs/ubuntu.md)
* [Deploy the fedora on vm](docs/fedora.md)
* [Deploy the rhel9 on vm](docs/rhel.md)


## How to deploy Vms using Gitlab pipelines

Edit and run the trigger pipeline to trigger a build.


![20230527093215](https://i.imgur.com/I9ERA5a.png)

```bash
$ vim trigger-pipeline.sh

TOKEN="GITLAB-TOKEN"
SSH_PASSWORD="MACHINE_PASSWORD"
TARGET_SERVER=equinix
SSH_HOST="192.168.1.25"
SSH_USER="lab-user"
ACTION=create #delete
```

Run thhe pipeline
```
$ ./trigger-pipeline.sh
```
