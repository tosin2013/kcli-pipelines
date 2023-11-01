# Deploy the ocp4-disconnected-helper   on vm

This repository provides some automation and other utilities to deploy OpenShift in a disconnected environment.

[OpenShift 4 Disconnected Helper](https://github.com/kenmoini/ocp4-disconnected-helper)


## Requirements
* A Machine configured with kcli via [qubinode_navigator](https://github.com/tosin2013/qubinode_navigator)
* freeipa to be used for DNS

### switch to root
```
$ sudo su - 
```

### Configure System 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="supermicro" # equinix 
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Configure rhel9 
![20230612121808](https://i.imgur.com/ho68kF9.png)
```
sudo kcli download image rhel9
```

### Deploy the ocp4-disconnected-helper source notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="rhel8-equinix" # equinix 
export VM_PROFILE=ocp4-disconnected-helper  
export VM_NAME="ocp4-disconnected-helper"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=ocp4-disconnected-helper  /g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=ocp4-disconnected-helper  /g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh

$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the ocp4-disconnected-helper  
```
# sudo kcli list vm 
+---------+--------+-----------------+--------+-------+---------+
|   Name  | Status |        Ip       | Source |  Plan | Profile |
+---------+--------+-----------------+--------+-------+---------+
| freeipa |   up   | 192.168.122.189 | rhel8  | kvirt | freeipa |
|  harbor |   up   | 192.168.122.143 | rhel9  | kvirt |  harbor |
+---------+--------+-----------------+--------+-------+---------+

# sudo kcli ssh harbor
$ sudo docker ps 
```

### Delete Deployment 
```
$ source notouch.env
$ export  ACTION="delete" &&  sudo -E  ./deploy-vm.sh
```

### Troubleshooting Deployment
```
$ sudo kcli list vm
$ sudo kcli ssh ocp4-disconnected-helper  
$ cat  /tmp/install.log
$ sudo vim /opt/kcli-pipelines/helper_scripts/hosts
$ sudo kcli delete vm ocp4-disconnected-helper  
``` 

**You can also run with out tumx using the command below**
```
source notouch.env  && sudo -E  ./deploy-vm.sh
``

https://access.redhat.com/downloads/content/480/ver=2.3/rhel---9/2.3/x86_64/product-software
