# Deploy the microshift-demos on vm

This repo contains demos of various MicroShift features.

hello-microshift-demo: Demonstrates a minimal RHEL for Edge with MicroShift and deploying a "Hello, MicroShift!" app on it.
ostree-demo: Become familiar with rpm-ostree basics (image building, updates&rollbacks, etc.) and "upgrading into MicroShift".
e2e-demo: (outdated!) Demonstrates the end-to-end process from device provisioning to management via GitOps and ACM.
ibaas-demo: Build a RHEL for Edge ISO containing MicroShift and its dependencies in a completely automated manner using Red Hat's Hosted Image Builder service from console.redhat.com.

Github: https://github.com/redhat-et/microshift-demos

## Requirements
* A Machine configured with kcli via [qubinode_navigator](https://github.com/tosin2013/qubinode_navigator)
* freeipa-server-container to be used for DNS

### switch to root
```
$ sudo su - 
```

### Configure System 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="equinix" # equinix 
export COMMUNITY_VERSION="false" # Set to true if you do not have access to Red Hat Activation Keys\r\n\r\nhttps://access.redhat.com/articles/1378093"
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Configure rhel9 
![20230613003134](https://i.imgur.com/F5WRBU4.png)
```
sudo kcli download image rhel9
```
### Deploy the microshift-demos source notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="machine_name" # equinix 
export VM_PROFILE=microshift-demos
export VM_NAME="microshift-demos"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=microshift-demos/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=microshift-demos/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh

$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the microshift-demos
```
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   | 192.168.122.109 | Fedora-Server-KVM-40-1.14.x86_64.qcow2 | kvirt | freeipa-server-container |
|     microshift-demos     |   up   |  192.168.122.95 |                 rhel9                 | kvirt |     microshift-demos     |
|     mirror-registry      |   up   |  192.168.122.92 | Fedora-Server-KVM-40-1.14.x86_64.qcow2 | kvirt |     mirror-registry      |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
# sudo kcli ssh microshift-demos
$ sudo su - 
$ ls
microshift-demos  offline_token  setup-demo-infra.sh
$ cd microshift-demos/
```

### TroubleShooting
If the deployment fails using tmux run the following commands
```
$ sudo kcli list vm
$ sudo kcli delete vm microshift-demos
$ source notouch.env  && sudo -E  ./deploy-vm.sh
```
=======
=======
### Delete Deployment 
```
$ source notouch.env
$ export  ACTION="delete" 
$ sudo -E  ./deploy-vm.sh
```

### Default DNS Endpoint
* https:/microshift-demos.your-domainname.com:9090
