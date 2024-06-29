# Deploy the VyOS router on vm

VyOS is an open source network operating system based on Debian GNU/Linux.

VyOS provides a free routing platform that competes directly with other commercially available solutions from well known network providers. Because VyOS runs on standard amd64, i586 and ARM systems, it is able to be used as a router and firewall platform for cloud deployments.

[Website](https://vyos.io/)
[Docs](https://docs.vyos.io/en/latest/index.html#)

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
export TARGET_SERVER="rhel8-equinix" # equinix 
export COMMUNITY_VERSION="false" # Set to true if you do not have access to Red Hat Activation Keys\r\n\r\nhttps://access.redhat.com/articles/1378093"
EOF

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/configure-kcli-profiles.sh && chmod +x configure-kcli-profiles.sh
$ source notouch.env && sudo -E  ./configure-kcli-profiles.sh 
```


### Deploy the vyos
```
$ cat >notouch.env<<EOF
export CICD_PIPELINE="true" 
export TARGET_SERVER="rhel8-equinix" # equinix 
export VM_PROFILE=vyos-router
export VM_NAME="vyos-router"
export  ACTION="create" # create, delete
EOF

or 
$ sed -i 's/export VM_NAME=.*/export VM_NAME=vyos-$(echo $RANDOM | md5sum | head -c 5; echo;)/g' notouch.env
$ sed -i 's/export VM_PROFILE=.*/export VM_PROFILE=vyos/g' notouch.env

$ curl -OL https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/deploy-vm.sh && chmod +x deploy-vm.sh
$ tmux new-session -d -s deploy-vm 'source notouch.env  && sudo -E  ./deploy-vm.sh'
$ tmux attach -t deploy-vm
```

### Validate the vyos
**Default username and password**
* username: vyos
* password: vyos

![20240427110356](https://i.imgur.com/PdnTynQ.png)
![20240427100635](https://i.imgur.com/ZJzE1Lp.png)
![20240427100654](https://i.imgur.com/aAmRFWl.png)
![20240427101101](https://i.imgur.com/FA2rwXB.png)
![20240427101254](https://i.imgur.com/7yLOY8J.png)
![20240427101353](https://i.imgur.com/vmXQ8TE.png)
![20240427101428](https://i.imgur.com/PHT8DFo.png)
![20240427101509](https://i.imgur.com/Tp970x3.png)

### Delete Deployment 
```
$ source notouch.env && export  ACTION="delete" && sudo -E  ./deploy-vm.sh
```
