# VM 

## Requiremetns 
```
ansible-galaxy collection install community.libvirt
```

```
sudo pip3 install libvirt-python
sudo pip3 install lxml
sudo yum install libvirt-devel -y
```

## Run the playbook 
```
sudo -E /usr/bin/ansible-playbook  create-blank-instance/configure-blank-instance.yaml
```