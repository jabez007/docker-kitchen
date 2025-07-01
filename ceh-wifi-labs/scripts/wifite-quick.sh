#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    echo "WiFi penetration testing requires root privileges to access network interfaces"
    exit 1
fi

# Check if wifite is available and executable
if ! command -v wifite &>/dev/null; then
    echo "Error: wifite is not installed or not in PATH"
    echo "Please install wifite: apt-get install wifite"
    exit 1
fi

# Check if wordlist file exists
readonly WORDLIST="/opt/wordlists/rockyou.txt"
if [ ! -f "$WORDLIST" ]; then
    echo "Error: Wordlist file not found: $WORDLIST"
    echo "Please ensure the wordlist is downloaded or specify a different wordlist"
    exit 1
fi

# Quick wifite attack
if [ $# -lt 1 ]; then
    echo "Usage: $0 <interface> [wifite-options]"
    exit 1
fi

INTERFACE=$1
shift
echo "Starting wifite on $INTERFACE"
wifite --interface "$INTERFACE" --crack --dict "$WORDLIST" "$@"
