# Deploy the kcli-openshift4-baremetal on vm

This repository provides a plan which deploys a vm where:

openshift-baremetal-install is downloaded or compiled from source (with an additional list of PR numbers to apply)
stop the nodes to deploy through redfish or ipmi
launch the install against a set of baremetal nodes. Virtual ctlplanes and workers can also be deployed.
The automation can be used for additional scenarios:

only deploying the virtual infrastructure needed for a baremetal ipi deployment
deploying a spoke cluster (either multinodes or SNO) through ZTP on top of the deployed Openshift


Github:
 * https://github.com/tosin2013/kcli-openshift4-baremetal


## Requirements
* A Machine configured with kcli via [qubinode_navigator](https://github.com/tosin2013/qubinode_navigator)

### switch to root
```
$ sudo su - 
```

### Configure System 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="supermicro" # equinix
export COMMUNITY_VERSION="false" # Set to true if you do not have access to Red Hat Activation Keys\r\n\r\nhttps://access.redhat.com/articles/1378093" 
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Deploy the kcli-openshift4-baremetal source notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="rhel8-equinix" # equinix 
export VM_PROFILE=kcli-openshift4-baremetal
export VM_NAME="kcli-openshift4-baremetal"
export ACTION="create" # create, delete
export DEPLOY_OPENSHIFT=true
export LAUNCH_STEPS=true
export TAG='4.13'
export DISCONNECTED_INSTALL=false
export DEPLOYMENT_CONFIG="cnv-kcli-openshift4-baremetal.yml"
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=kcli-openshift4-baremetal/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=kcli-openshift4-baremetal/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh

$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the kcli-openshift4-baremetal
```
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   | 192.168.122.109 | Fedora-Server-KVM-40-1.14.x86_64.qcow2 | kvirt | freeipa-server-container |
|     kcli-openshift4-baremetal          |   up   |  192.168.122.95 |                 rhel9                 | kvirt |     kcli-openshift4-baremetal          |
|     mirror-registry      |   up   |  192.168.122.92 | Fedora-Server-KVM-40-1.14.x86_64.qcow2 | kvirt |     mirror-registry      |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
# sudo kcli ssh kcli-openshift4-baremetal
$ cat  /opt/aap_info.txt
```

### Delete Deployment 
```
$ source notouch.env
$ export  ACTION="delete" 
$ sudo -E  ./deploy-vm.sh
```

### Troubleshooting Deployment
```
$ sudo kcli list vm
$ sudo kcli ssh kcli-openshift4-baremetal
$ cat  /tmp/install.log
$ sudo vim /opt/kcli-pipelines/helper_scripts/hosts
$ sudo kcli delete vm kcli-openshift4-baremetal
``` 

**You can also run with out tumx using the command below**
```
source notouch.env  && sudo -E  ./deploy-vm.sh
``

https://access.redhat.com/downloads/content/480/ver=2.3/rhel---9/2.3/x86_64/product-software
