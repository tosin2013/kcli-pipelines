# Deploy the rhel9-pxe on vm

OpenShift Jumpbox VMS contains different tools to help with the installation and management of OpenShift clusters.

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
export TARGET_SERVER="rhel8-equinix" # equinix 
export COMMUNITY_VERSION="false" # Set to true if you do not have access to Red Hat Activation Keys\r\n\r\nhttps://access.redhat.com/articles/1378093"
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```


### Deploy the rhel9-pxe
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="rhel8-equinix" # equinix 
export VM_PROFILE=rhel9-pxe
export VM_NAME="rhel9-pxe-$(echo $RANDOM | md5sum | head -c 5; echo;)"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=rhel9-pxe-$(echo $RANDOM | md5sum | head -c 5; echo;)/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=rhel9-pxe/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh
$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the rhel9-pxe
```tmux attach -t deploy-vm
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   |  192.168.1.119  | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt | freeipa-server-container |
|       rhel9-pxe-b5777       |   up   | 192.168.122.220 |                 rhel9-pxe                | kvirt |          rhel9-pxe          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+


# sudo kcli ssh rhel9-pxe-b5777
```

### Delete Deployment 
```
$ source notouch.env
$ export  ACTION="delete" 
$ sudo -E  ./deploy-vm.sh
```
