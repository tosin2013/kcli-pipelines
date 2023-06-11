# Deploy the ansible-aap on vm

Red Hat® Ansible® Automation Platform is an end-to-end automation platform to configure systems, deploy software, and orchestrate advanced workflows. It includes resources to create, manage, and scale across the entire enterprise.

Github:
 * https://github.com/redhat-cop/agnosticd/tree/development/ansible/roles/aap_download


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

### Deploy the ansible-aap source notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="supermicro" # equinix 
export VM_NAME="ansible-aap"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=ansible-aap/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh

$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the ansible-aap
```
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   | 192.168.122.109 | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt | freeipa-server-container |
|     ansible-aap          |   up   |  192.168.122.95 |                 rhel9                 | kvirt |     ansible-aap          |
|     mirror-registry      |   up   |  192.168.122.92 | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt |     mirror-registry      |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
# sudo kcli ssh ansible-aap
$ cat  /opt/aap_info.txt
```

### Troubleshooting Deployment
```
$ sudo kcli list vm
$ sudo kcli ssh ansible-aap
$ cat  /tmp/install.log
$ sudo vim /opt/kcli-pipelines/helper_scripts/hosts
$ sudo kcli delete vm ansible-aap
``` 

https://access.redhat.com/downloads/content/480/ver=2.3/rhel---9/2.3/x86_64/product-software
