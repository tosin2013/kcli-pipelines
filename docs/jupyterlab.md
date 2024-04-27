# Deploy the jupyterlab on vm

JupyterLab is a highly extensible, feature-rich notebook authoring application and editing environment, and is a part of Project Jupyter, a large umbrella project centered around the goal of providing tools (and standards) for interactive computing with computational notebooks.

https://jupyterlab.readthedocs.io/en/latest/

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

### Deploy the jupyterlab
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="machine_name" # equinix 
export VM_PROFILE=jupyterlab
export VM_NAME="jupyterlab-$(echo $RANDOM | md5sum | head -c 5; echo;)"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=jupyterlab-$(echo $RANDOM | md5sum | head -c 5; echo;)/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=jupyterlab/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh
$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the jupyterlab
```tmux attach -t deploy-vm
# sudo kcli list vm 
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
|           Name           | Status |        Ip       |                 Source                |  Plan |         Profile          |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+
| freeipa-server-container |   up   |  192.168.1.119  | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt | freeipa-server-container |
|     jupyterlab-f0547     |   up   | 192.168.122.183 | Fedora-Cloud-Base-38-1.6.x86_64.qcow2 | kvirt |        jupyterlab        |
+--------------------------+--------+-----------------+---------------------------------------+-------+--------------------------+

# sudo kcli ssh jupyterlab-f0547 
# /tmp/configure_env.sh
# cat /var/log/jupyter-lab.log  | grep token
```

### Delete Deployment 
```
$ source notouch.env
$ export  ACTION="delete" 
$ sudo -E  ./deploy-vm.sh
```