# Deploy the freeipa-server-container on vm

Github: https://github.com/freeipa/freeipa-container

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
export TARGET_SERVER="equinix" # equinix
export COMMUNITY_VERSION="false" # Set to true if you do not have access to Red Hat Activation Keys\r\n\r\nhttps://access.redhat.com/articles/1378093"
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Deploy the freeipa-server-containersource notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="hetzner" # hetzner, equinix
export VM_PROFILE="freeipa"
export VM_NAME="freeipa"
export  ACTION="create" # create, delete
EOF
$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh
$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the freeipa-server-container
```
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   | 192.168.122.109 | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt | freeipa-server-container |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+

# sudo kcli ssh freeipa-server-container
```

### TroubleShooting
If the deployment fails using tmux run the following commands
```
$ sudo kcli list vm
$ sudo kcli delete vm freeipa-server-container
$ source notouch.env  && sudo -E  ./deploy-vm.sh
```
### Default DNS Endpoint
* https://ipa.your-domainname.com