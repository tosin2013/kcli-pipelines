#!/bin/bash 
# https://github.com/boliu83/ipxe-boot-server

cat >/tftpboot/menu/boot.ipxe<<EOF
#!ipxe

menu PXE Boot Options

item shell iPXE shell
item exit  Exit to BIOS

choose --default exit --timeout 10000 option && goto ${option}

:shell
shell

:exit
exit
EOF

OCTECTS="192.168.40"
LAST_OCTECT="2"
DOMAIN="homelab.net"
BOOT_MENU="menu/boot.ipxe"
cat >/etc/dnsmasq.conf<<EOF
# enable logs if required
#log-queries
#log-dhcp

# disable DNS server
port=0

# listen on PXEBOOT vlan (vlan110) only
listen-address=${OCTECTS}.${LAST_OCTECT}
interface=eth1

# enable built-in tftp server
enable-tftp
tftp-root=/tftpboot


# DHCP range ${OCTECTS}.200 ~ ${OCTECTS}.250
dhcp-range=${OCTECTS}.200,${OCTECTS}.250,255.255.255.0,24h

# Default gateway
dhcp-option=3,${OCTECTS}.1

# Domain name - ${DOMAIN}
dhcp-option=15,${DOMAIN}

# Broadcast address
dhcp-option=28,${OCTECTS}.255

# Set interface MTU to 9000 bytes (jumbo frame)
# Enable only when your network supports it
# dhcp-option=26,9000

# Tag dhcp request from iPXE
dhcp-match=set:ipxe,175

# inspect the vendor class string and tag BIOS client
dhcp-vendorclass=BIOS,PXEClient:Arch:00000

# 1st boot file - Legacy BIOS client
dhcp-boot=tag:!ipxe,tag:BIOS,undionly.kpxe,${OCTECTS}.${LAST_OCTECT}

# 1st boot file - EFI client
# at the moment all non-BIOS clients are considered
# EFI client
dhcp-boot=tag:!ipxe,tag:!BIOS,ipxe.efi,${OCTECTS}.${LAST_OCTECT}

# 2nd boot file
dhcp-boot=tag:ipxe,${BOOT_MENU}
EOF

systemctl start firewalld && systemctl enable firewalld

sudo firewall-cmd --add-service=dhcp --permanent
sudo firewall-cmd --add-service=tftp --permanent
sudo firewall-cmd --add-service=dns --permanent
sudo firewall-cmd --reload

sudo systemctl start dnsmasq
sudo systemctl status dnsmasq
