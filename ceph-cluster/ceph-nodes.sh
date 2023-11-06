#!/bin/bash
sudo subscription-manager refresh
sudo subscription-manager attach --auto
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-9-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms
dnf update -y
subscription-manager repos --enable=rhceph-6-tools-for-rhel-9-x86_64-rpms