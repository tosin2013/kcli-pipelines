# Deploy the openshift-agent-install on vm

Red Hat Ceph Storage is an open, massively scalable, highly available and resilient distributed storage solution for modern data pipelines. Engineered for data analytics, artificial intelligence/machine learning (AI/ML), and hybrid cloud workloads, Red Hat Ceph Storage delivers software-defined storage for both containers and virtual machines on your choice of industry-standard hardware.

Product Documentation for Red Hat Ceph Storage 6:
 * https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/6


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
export COMMUNITY_VERSION="false" # Set to true if you do not have access to Red Hat Activation Keys\r\n\r\nhttps://access.redhat.com/articles/1378093"
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Configure rhel9 
![20230612121808](https://i.imgur.com/ho68kF9.png)
```
sudo kcli download image rhel9
```

### Deploy the openshift-agent-install source notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="rhel8-equinix" # equinix 
export VM_PROFILE=openshift-agent-install
export VM_NAME="openshift-agent-install"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=openshift-agent-install/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=openshift-agent-install/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh

$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the openshift-agent-install
```
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   | 192.168.122.109 | Fedora-Server-KVM-40-1.14.x86_64.qcow2 | kvirt | freeipa-server-container |
|     openshift-agent-install          |   up   |  192.168.122.95 |                 rhel9                 | kvirt |            |
|     mirror-registry      |   up   |  192.168.122.92 | Fedora-Server-KVM-40-1.14.x86_64.qcow2 | kvirt |     mirror-registry      |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
# sudo kcli ssh openshift-agent-install
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
$ sudo kcli ssh openshift-agent-install
$ cat  /tmp/install.log
$ sudo vim /opt/kcli-pipelines/helper_scripts/hosts
$ sudo kcli delete vm openshift-agent-install
``` 

**You can also run with out tumx using the command below**
```
source notouch.env  && sudo -E  ./deploy-vm.sh
```

https://access.redhat.com/downloads/content/480/ver=2.3/rhel---9/2.3/x86_64/product-software
