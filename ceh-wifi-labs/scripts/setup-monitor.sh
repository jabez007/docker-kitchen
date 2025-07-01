#!/bin/bash
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
airmon-ng start $INTERFACE
echo "Monitor mode setup complete"
