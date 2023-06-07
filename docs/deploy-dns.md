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
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```

### Deploy the freeipa-server-containersource notouch.env 
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="machine_name" # equinix 
export VM_NAME="freeipa-server-container"
export  ACTION="create" # create, delete
EOF
$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh
$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```