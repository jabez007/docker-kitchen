#!/bin/bash
set -euo pipefail

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    echo "WiFi monitoring requires root privileges to access network interfaces"
    exit 1
fi

# Check if airodump-ng is available
if ! command -v airodump-ng &> /dev/null; then
    echo "Error: airodump-ng is not installed or not in PATH"
    echo "Please install aircrack-ng suite: apt-get install aircrack-ng"
    exit 1
fi

# Quick WiFi network scan
if [ $# -eq 0 ]; then
    echo "Usage: $0 <monitor_interface>"
    exit 1
fi

INTERFACE=$1
echo "Starting quick scan on $INTERFACE"
echo "Press Ctrl+C to stop scanning"
airodump-ng "$INTERFACE"
