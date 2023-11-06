#!/bin/bash

if [ $# -ne 3 ]; then 
    echo "No arguments provided"
    echo "Usage: $0 <rhel_username> <rhel_password> <domain_name>"
    exit 1
fi
rhsm_username=${1}
rhsm_password=${2}
domain_name=${3}
sudo subscription-manager refresh
sudo subscription-manager attach --auto
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-9-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms
dnf update -y
subscription-manager repos --enable=rhceph-6-tools-for-rhel-9-x86_64-rpms
dnf install ansible-core cephadm-ansible bind-utils -y

curl https://raw.githubusercontent.com/tosin2013/kcli-pipelines/main/ceph-cluster/rhel9_ceph.sh --output /tmp/rhel9_ceph.sh

chmod +x /tmp/rhel9_ceph.sh

sed -i "s/RHEL_USERNAME/${rhsm_username}/g"  /tmp/rhel9_ceph.sh
sed -i "s/RHEL_PASSWORD/${rhsm_password}/g"  /tmp/rhel9_ceph.sh
sed -i "s/CHANGE_DOMAIN/${domain_name}/g"  /tmp/rhel9_ceph.sh