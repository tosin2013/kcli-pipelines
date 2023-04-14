# Configure Ansible Automation Platform and Ansible Hub

```bash
$ ./deploy-vms.sh
$ sudo kcli ssh ansible-aap
$ sudo su - root
$ chmod +x /tmp/setup-aap.sh
$ /tmp/setup-aap.sh
```


Delete the plan
```
KILLME=$(sudo kcli list plan | grep -P -i [A-Za-z0-9]+-[A-Za-z0-9] | awk '{print $2}')
sudo kcli delete plan ${KILLME}
```