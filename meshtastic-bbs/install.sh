#!/bin/bash

# Meshtastic Setup Script for Raspberry Pi
# This script installs and configures Meshtastic on a Raspberry Pi with a compatible LoRa HAT.
# Web server support is optional and can be included using the -w flag.

# Global variables
MESHTASTIC_VERSION="2.5.15.79da236"  # Update this to the desired Meshtastic version
MESHTASTIC_DEB="meshtasticd_${MESHTASTIC_VERSION}_arm64.deb"
MESHTASTIC_URL="https://github.com/meshtastic/firmware/releases/download/v${MESHTASTIC_VERSION}/${MESHTASTIC_DEB}"
CONFIG_FILE="/etc/meshtasticd/config.yaml"
INCLUDE_WEB_SERVER=false

# Function to check if the script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        printf "This script must be run as root. Please run with sudo or as root user.\n" >&2
        exit 1
    fi
}

# Function to parse script arguments
parse_arguments() {
    while getopts "w" opt; do
        case $opt in
            w)
                INCLUDE_WEB_SERVER=true
                ;;
            *)
                printf "Usage: $0 [-w]\n"
                printf "  -w  Include web server dependencies and configuration\n"
                exit 1
                ;;
        esac
    done
}

# Function to update and install necessary system libraries
install_dependencies() {
    apt update && apt install -y \
        libgpiod-dev \
        libyaml-cpp-dev \
        libbluetooth-dev \
        libusb-1.0-0-dev \
        libi2c-dev

    if $INCLUDE_WEB_SERVER; then
        apt install -y \
            openssl \
            libssl-dev \
            libulfius-dev \
            liborcania-dev
    fi
}

# Function to download and install Meshtasticd
install_meshtasticd() {
    wget "$MESHTASTIC_URL" -O "/tmp/$MESHTASTIC_DEB"
    if [[ -f "/tmp/$MESHTASTIC_DEB" ]]; then
        apt install -y "/tmp/$MESHTASTIC_DEB"
    else
        printf "Failed to download Meshtasticd package. Exiting.\n" >&2
        exit 1
    fi
}

# Function to enable SPI and I2C interfaces
enable_interfaces() {
    raspi-config nonint set_config_var dtparam=spi on /boot/firmware/config.txt
    raspi-config nonint set_config_var dtparam=i2c_arm on /boot/firmware/config.txt

    # Ensure dtoverlay=spi0-0cs is set in /boot/firmware/config.txt without altering dtoverlay=vc4-kms-v3d or dtparam=uart0
    sed -i -e '/^\s*#\?\s*dtoverlay\s*=\s*vc4-kms-v3d/! s/^\s*#\?\s*(dtoverlay|dtparam\s*=\s*uart0)\s*=.*/dtoverlay=spi0-0cs/' /boot/firmware/config.txt

    if ! grep -q '^\s*dtoverlay=spi0-0cs' /boot/firmware/config.txt; then
        sed -i '/^\s*dtparam=spi=on/a dtoverlay=spi0-0cs' /boot/firmware/config.txt
    fi
}

# Function to configure Meshtasticd
configure_meshtasticd() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        sed -i '/^#\?Lora:/,/^$/ s/^#//' "$CONFIG_FILE"
        sed -i 's/^  Module:.*/  Module: sx1262/' "$CONFIG_FILE"
        sed -i 's/^  DIO2_AS_RF_SWITCH:.*/  DIO2_AS_RF_SWITCH: true/' "$CONFIG_FILE"
        sed -i 's/^  CS:.*/  CS: 21/' "$CONFIG_FILE"
        sed -i 's/^  IRQ:.*/  IRQ: 16/' "$CONFIG_FILE"
        sed -i 's/^  Busy:.*/  Busy: 20/' "$CONFIG_FILE"
        sed -i 's/^  Reset:.*/  Reset: 18/' "$CONFIG_FILE"
    else
        printf "Configuration file not found at %s. Exiting.\n" "$CONFIG_FILE" >&2
        exit 1
    fi

    if $INCLUDE_WEB_SERVER; then
        sed -i '/^#\?WebServer:/,/^$/ s/^#//' "$CONFIG_FILE"
        sed -i 's/^  Enabled:.*/  Enabled: true/' "$CONFIG_FILE"
        sed -i 's/^  BindAddress:.*/  BindAddress: 0.0.0.0/' "$CONFIG_FILE"
        sed -i 's/^  Port:.*/  Port: 8080/' "$CONFIG_FILE"
    fi
}

# Function to restart Meshtasticd service
restart_service() {
    systemctl restart meshtasticd
    systemctl enable meshtasticd
}

# Main function
main() {
    check_root
    parse_arguments "$@"
    install_dependencies
    install_meshtasticd
    enable_interfaces
    configure_meshtasticd
    restart_service
    printf "Meshtastic setup completed successfully.\n"
}

# Execute main function
main "$@"
