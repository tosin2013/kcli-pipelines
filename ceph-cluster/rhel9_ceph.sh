#!/bin/bash 

PASSWORD='CHANGE_PASSWORD'
# Define the new resolv.conf content
NEW_RESOLV_CONF="nameserver DNS_ENDPOINT"

if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
    for i in {1..3}
    do
        echo ceph-mon0${i}.CHANGE_DOMAIN
        sshpass -p $PASSWORD ssh-copy-id -o StrictHostKeyChecking=no root@ceph-mon0${i}.CHANGE_DOMAIN
        ssh root@ceph-mon0${i}.CHANGE_DOMAIN "bash -c 'echo -e \"$NEW_RESOLV_CONF\" | sudo tee /etc/resolv.conf > /dev/null'"
        echo ceph-osd0${i}.CHANGE_DOMAIN
        sshpass -p $PASSWORD ssh-copy-id -o StrictHostKeyChecking=no root@ceph-osd0${i}.CHANGE_DOMAIN
        ssh root@ceph-osd0${i}.CHANGE_DOMAIN "bash -c 'echo -e \"$NEW_RESOLV_CONF\" | sudo tee /etc/resolv.conf > /dev/null'"
    done
fi


cd /usr/share/cephadm-ansible

cat >hosts<<EOF
ceph-mon02.CHANGE_DOMAIN labels="['mon', 'mgr']"
ceph-mon03.CHANGE_DOMAIN  labels="['mon', 'mgr']"
ceph-osd01.CHANGE_DOMAIN  labels="['osd']"
ceph-osd02.CHANGE_DOMAIN  labels="['osd']"
ceph-osd03.CHANGE_DOMAIN  labels="['osd']"

[admin]
ceph-mon01.CHANGE_DOMAIN  monitor_address=ceph-mon01.CHANGE_DOMAIN  labels="['_admin', 'mon', 'mgr']"
EOF

ansible-playbook -i hosts cephadm-preflight.yml --extra-vars "ceph_origin=rhcs"  --extra-vars "ceph_rhcs_version=6" -vvv || exit $?


ansible-galaxy collection install containers.podman

cat >bootstrap-nodes.yml<<EOF
---
- name: bootstrap the nodes
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: login to registry
      cephadm_registry_login:
        state: login
        docker: false
        registry_url: registry.redhat.io
        registry_username: RHEL_USERNAME
        registry_password: RHEL_PASSWORD
    - name: Login to default registry and create ${XDG_RUNTIME_DIR}/containers/auth.json
      containers.podman.podman_login:
        username: RHEL_USERNAME
        password: RHEL_PASSWORD
        registry: registry.redhat.io
EOF


ansible-playbook -i hosts bootstrap-nodes.yml -vvv || exit $?
cephadm bootstrap --mon-ip $(hostname -I)  --allow-fqdn-hostname | tee -a /root/cephadm_bootstrap.log
cephadm shell ceph -s
ceph -s

#ceph cephadm get-pub-key > ~/ceph.pub
ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(dig ceph-mon02.CHANGE_DOMAIN +short)
ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(dig ceph-mon03.CHANGE_DOMAIN +short)
ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(dig ceph-osd01.CHANGE_DOMAIN +short)
ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(dig ceph-osd02.CHANGE_DOMAIN +short)
ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(dig ceph-osd03.CHANGE_DOMAIN +short)
ceph orch host add ceph-mon02 $(dig ceph-mon02.CHANGE_DOMAIN +short)
ceph orch host add ceph-mon03 $(dig ceph-mon03.CHANGE_DOMAIN +short)
ceph orch host label add ceph-mon01 mon
ceph orch host label add ceph-mon02 mon
ceph orch host label add ceph-mon03 mon
ceph orch apply mon ceph-mon01,ceph-mon02,ceph-mon03
ceph orch host ls 
ceph orch host rescan ceph-mon02 --with-summary
ceph orch host rescan ceph-mon03 --with-summary
ceph orch ps
#ceph orch resume
#ceph cephadm check-host ceph-mon02
echo "waiting 120s for mons to be up"
sleep 120s
ceph orch host add ceph-osd01 $(dig ceph-osd01.CHANGE_DOMAIN +short)
ceph orch host add ceph-osd02 $(dig ceph-osd02.CHANGE_DOMAIN +short)
ceph orch host add ceph-osd03 $(dig ceph-osd03.CHANGE_DOMAIN +short)
ceph orch host label add ceph-osd01 osd
ceph orch host label add ceph-osd02 osd
ceph orch host label add ceph-osd03 osd
echo "waiting 120s for osds to be up"
sleep 120s
ceph orch apply osd --all-available-devices
#ceph orch daemon add osd ceph-osd01:/dev/vdb
#ceph orch daemon add osd ceph-osd02:/dev/vdb
#ceph orch daemon add osd ceph-osd03:/dev/vdb
echo "waiting 120s for osds to be up"
sleep 120s 
ceph osd tree
echo "configuring ocs pool"
ceph osd pool create ocs 64 64
#ceph osd pool application enable ocs rbd



