# Deploy the device-edge-workshops on vm

The Red Hat Ansible Automation Workshops project is intended for effectively demonstrating Red Hat's Device Edge capabilities through instructor-led workshops or self-paced exercises.

Github: https://github.com/redhat-manufacturing/device-edge-workshops

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

### Configure rhel9 
![20230612121808](https://i.imgur.com/ho68kF9.png)
```
sudo kcli download image rhel9
```

### Deploy the device-edge-workshops source notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="rhel8-equinix" # equinix 
export VM_PROFILE=device-edge-workshops
export VM_NAME="device-edge-workshops"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=device-edge-workshops/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=device-edge-workshops/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh

$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
$ sudo kcli scp /tmp/baremetal-playbooks/ device-edge-workshops:/tmp
```


### Validate the device-edge-workshops
```
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   | 192.168.122.109 | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt | freeipa-server-container |
|  device-edge-workshops   |   up   |  192.168.122.95 |                 rhel9                 | kvirt |     device-edge-workshops     |
|     mirror-registry      |   up   |  192.168.122.92 | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt |     mirror-registry      |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
# sudo kcli scp /tmp/baremetal-playbooks device-edge-workshops:/tmp
$ sudo kcli ssh device-edge-workshops
$ sudo su - 
$ ls
device-edge-workshops  offline_token  setup-demo-infra.sh
$ cd device-edge-workshops/
$ ./setup-demo-infra.sh
```

### TroubleShooting
If the deployment fails using tmux run the following commands
```
$ sudo kcli list vm
$ sudo kcli delete vm device-edge-workshops
$ source notouch.env
$ sudo kcli create vm -p $VM_PROFILE $VM_NAME -P dns=${DNS_ADDRESS} --wait
```
