#!/bin/bash
# Quick wifite attack
if [ $# -eq 0 ]; then
    echo "Usage: $0 <interface>"
    exit 1
fi

INTERFACE=$1
echo "Starting wifite on $INTERFACE"
wifite --interface "$INTERFACE" --crack --dict /opt/wordlists/rockyou.txt
