# Deploy the fedora38 on vm

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
export TARGET_SERVER="equinix" # equinix 
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Deploy the fedora38
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="supermicro" # equinix 
export VM_PROFILE=fedora38
export VM_NAME="fedora38-$(echo $RANDOM | md5sum | head -c 5; echo;)"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=fedora38-$(echo $RANDOM | md5sum | head -c 5; echo;)/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=fedora38/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh
$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the fedora38
```tmux attach -t deploy-vm
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   |  192.168.1.119  | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt | freeipa-server-container |
|       fedora38-b5777       |   up   | 192.168.122.220 |                 fedora38                | kvirt |          fedora38          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+


# sudo kcli ssh fedora38-b5777
```

### Delete Deployment 
```
$ source notouch.env
$ export  ACTION="delete" 
$ sudo -E  ./deploy-vm.sh
```