#!/bin/bash
set -euo pipefail
# Quick WiFi network scan
if [ $# -eq 0 ]; then
    echo "Usage: $0 <monitor_interface>"
    exit 1
fi

INTERFACE=$1
echo "Starting quick scan on $INTERFACE"
echo "Press Ctrl+C to stop scanning"
airodump-ng "$INTERFACE"
