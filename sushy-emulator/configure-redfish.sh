#!/bin/bash

# Function to install requirements
install_requirements() {
    echo "Installing required packages..."
    sudo dnf install bind-utils libguestfs-tools cloud-init -yy
    if ! sudo dnf module install virt -yy; then
        echo "Failed to install virt module. Trying to install virt-install package..."
        sudo dnf install virt-install -yy
    fi
    sudo systemctl enable libvirtd --now
}

# Function to install Podman
install_podman() {
    echo "Installing Podman..."
    sudo dnf install podman -yy
}

# Function to create Sushy-Emulator configuration for KVM
create_sushy_config() {
    echo "Creating Sushy-Emulator configuration file for KVM..."
    sudo mkdir -p /etc/sushy/
    cat <<EOF | sudo tee /etc/sushy/sushy-emulator.conf
SUSHY_EMULATOR_LISTEN_IP = u'0.0.0.0'
SUSHY_EMULATOR_LISTEN_PORT = 8000
SUSHY_EMULATOR_SSL_CERT = None
SUSHY_EMULATOR_SSL_KEY = None
SUSHY_EMULATOR_OS_CLOUD = None
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu:///system'
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = True
SUSHY_EMULATOR_BOOT_LOADER_MAP = {
    u'UEFI': {
        u'x86_64': u'/usr/share/OVMF/OVMF_CODE.secboot.fd'
    },
    u'Legacy': {
        u'x86_64': None
    }
}
EOF
}

# Function to run Sushy-Emulator container for KVM
run_sushy_container() {
    echo "Running Sushy-Emulator container for KVM..."
    export SUSHY_TOOLS_IMAGE=${SUSHY_TOOLS_IMAGE:-"quay.io/metal3-io/sushy-tools"}
    sudo podman rm -f sushy-emulator 2>/dev/null || true
    sudo podman create --net host --privileged --name sushy-emulator -v "/etc/sushy":/etc/sushy -v "/var/run/libvirt":/var/run/libvirt "${SUSHY_TOOLS_IMAGE}" sushy-emulator -i :: -p 8000 --config /etc/sushy/sushy-emulator.conf
}

# Function to create systemd service
create_systemd_service() {
    echo "Creating systemd service for Sushy-Emulator..."
    sudo sh -c 'podman generate systemd --restart-policy=always -t 1 sushy-emulator > /etc/systemd/system/sushy-emulator.service'
    sudo systemctl daemon-reload
}

# Function to configure firewall
configure_firewall() {
    echo "Configuring firewall to allow Redfish API connections..."
    sudo systemctl start firewalld
    sudo firewall-cmd --add-port=8000/tcp --permanent
    sudo firewall-cmd --reload
}

# Function to verify installation
verify_installation() {
    echo "Verifying installation..."
    timeout 10s curl http://localhost:8000/redfish/v1/Managers
    if [ $? -ne 0 ]; then
        echo "Error: Failed to verify installation. Check the Sushy-Emulator service and configuration."
        exit 1
    fi
}

# Function to start the service
start_service() {
    echo "Starting Sushy-Emulator service..."
    sudo systemctl start sushy-emulator.service
    sudo systemctl status sushy-emulator.service
}

# Function to stop the service
stop_service() {
    echo "Stopping Sushy-Emulator service..."
    sudo systemctl stop sushy-emulator.service
}

# Function to restart the service
restart_service() {
    echo "Restarting Sushy-Emulator service..."
    sudo systemctl restart sushy-emulator.service
    sudo systemctl status sushy-emulator.service
}

# Function to test the installation
test_installation() {
    echo "Testing Sushy-Emulator installation..."
    verify_installation
    if [ $? -ne 0 ]; then
        echo "Error: Failed to test installation. Check the Sushy-Emulator service and configuration."
        exit 1
    fi
}

# Main script execution
case "$1" in
    install)
        install_requirements
        install_podman
        create_sushy_config
        run_sushy_container
        create_systemd_service
        configure_firewall
        start_service
        verify_installation
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    test)
        test_installation
        ;;
    *)
        echo "Usage: $0 {install|start|stop|restart|test}"
        exit 1
        ;;
esac

echo "Sushy-Emulator setup for KVM is complete!"

