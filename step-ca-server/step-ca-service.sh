#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Create the systemd service file
cat > /etc/systemd/system/step-ca.service << EOF
[Unit]
Description=Smallstep CA Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/step-ca /root/.step/config/ca.json --password-file=/etc/step/initial_password
StandardOutput=file:/tmp/step-ca.log
StandardError=file:/tmp/step-ca.log
Restart=always
RestartSec=10s
User=root
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize new or changed units
systemctl daemon-reload

# Enable the step-ca service to start at boot
systemctl enable step-ca

# Start the service right now
systemctl start step-ca

# Display status
systemctl status step-ca
