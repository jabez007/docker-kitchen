#!/bin/bash

# Meshtastic Setup Script for Raspberry Pi
# This script installs and configures Meshtastic on a Raspberry Pi with a compatible LoRa HAT.
# Web server support and Python CLI installation are optional and can be included using flags:
# -w for web server support
# -p for Python CLI installation

# Global variables
MESHTASTIC_VERSION="2.5.15.79da236"  # Update this to the desired Meshtastic version
MESHTASTIC_DEB="meshtasticd_${MESHTASTIC_VERSION}_arm64.deb"
MESHTASTIC_URL="https://github.com/meshtastic/firmware/releases/download/v${MESHTASTIC_VERSION}/${MESHTASTIC_DEB}"
CONFIG_FILE="/etc/meshtasticd/config.yaml"
INCLUDE_WEB_SERVER=false
INCLUDE_PYTHON_CLI=false

# Function to check if the script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        printf "This script must be run as root. Please run with sudo or as root user.\n" >&2
        exit 1
    fi
}

check_tools() {
    for tool in wget sed; do
        if ! command -v "$tool" &>/dev/null; then
            printf "Required tool '%s' is not installed. Please install it and re-run the script.\n" "$tool" >&2
            exit 1
        fi
    done
}

# Function to parse script arguments
parse_arguments() {
    while getopts "wp" opt; do
        case $opt in
            w)
                INCLUDE_WEB_SERVER=true
                ;;
            p)
                INCLUDE_PYTHON_CLI=true
                ;;
            *)
                printf "Usage: %s [-w] [-p]\n" "$0"
                printf "  -w  Include web server dependencies and configuration\n"
                printf "  -p  Install Python CLI for Meshtastic\n"
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

    if $INCLUDE_PYTHON_CLI; then
        apt install -y python3-pip pipx
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

# Function to install Meshtastic Python CLI
install_python_cli() {
    if ! pip install meshtastic; then
        printf "Failed to install Meshtastic Python CLI using pip. Attempting install using pipx.\n" >&2

        if ! pipx install meshtastic; then
            printf "Failed to install Meshtastic Python CLI using pipx. Exiting.\n" >&2
            exit 1
        fi

        # Ensure ~/.local/bin is in PATH
        pipx ensurepath
    fi
}

# Function to enable SPI and I2C interfaces
enable_interfaces() {
    raspi-config nonint set_config_var dtparam=spi on /boot/firmware/config.txt

    if ! grep -q '^\s*dtparam=spi=on' /boot/firmware/config.txt; then
        printf "Failed to enable SPI. Please check /boot/firmware/config.txt manually.\n" >&2
        exit 1
    fi

    raspi-config nonint set_config_var dtparam=i2c_arm on /boot/firmware/config.txt

    if ! grep -q '^\s*dtparam=i2c_arm=on' /boot/firmware/config.txt; then
        printf "Failed to enable I2C. Please check /boot/firmware/config.txt manually.\n" >&2
        exit 1
    fi

    # Ensure dtoverlay=spi0-0cs is set in /boot/firmware/config.txt without altering dtoverlay=vc4-kms-v3d or dtparam=uart0
    sed -i -e '/^\s*#\?\s*dtoverlay\s*=\s*vc4-kms-v3d/! s/^\s*#\?\s*(dtoverlay|dtparam\s*=\s*uart0)\s*=.*/dtoverlay=spi0-0cs/' /boot/firmware/config.txt

    # Insert dtoverlay=spi0-0cs after dtparam=spi=on if not already present
    if ! grep -q '^\s*dtoverlay=spi0-0cs' /boot/firmware/config.txt; then
        sed -i '/^\s*dtparam=spi=on/a dtoverlay=spi0-0cs' /boot/firmware/config.txt
    fi

    if ! grep -q '^\s*dtoverlay=spi0-0cs' /boot/firmware/config.txt; then
        printf "Failed to set dtoverlay=spi0-0cs. Please check /boot/firmware/config.txt manually.\n" >&2
        exit 1
    fi
}

# Function to restart Meshtasticd service
restart_service() {
    systemctl restart meshtasticd
    systemctl enable meshtasticd
}

# Main function
main() {
    exec > >(tee -i meshtastic_setup.log)
    exec 2>&1

    check_root
    check_tools
    parse_arguments "$@"
    install_dependencies
    enable_interfaces
    install_meshtasticd
    if $INCLUDE_PYTHON_CLI; then
        install_python_cli
    fi
    restart_service

    printf "Meshtastic setup completed successfully.\n"
    printf "To configure your LoRa module, edit the file:\n"
    printf "  sudo nano %s\n" "$CONFIG_FILE"
    printf "Refer to: https://meshtastic.org/docs/hardware/devices/linux-native-hardware\n"
}

main "$@"
