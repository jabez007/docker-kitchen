#!/bin/bash
set -euo pipefail

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    echo "Monitor mode setup requires root privileges to access network interfaces"
    exit 1
fi

# Script to set up monitor mode
if [ $# -eq 0 ]; then
    echo "Usage: $0 <interface>"
    echo "Available interfaces:"
    iw dev | grep Interface | cut -d' ' -f2
    exit 1
fi

INTERFACE=$1
echo "Setting up monitor mode on $INTERFACE"
airmon-ng check kill
airmon-ng start "$INTERFACE"

# Restart NetworkManager to restore network functionality
# echo "Restarting NetworkManager to restore network functionality..."
# systemctl restart NetworkManager

echo "Monitor mode setup complete"
