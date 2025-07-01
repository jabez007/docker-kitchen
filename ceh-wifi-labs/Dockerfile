# WiFi Penetration Testing Lab Environment
FROM kalilinux/kali-rolling:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color

# Update package lists and install base tools
RUN apt-get update && apt-get upgrade -y

# Install core system utilities
RUN apt-get install -y \
  curl \
  wget \
  git \
  vim \
  nano \
  htop \
  tree \
  unzip \
  build-essential \
  python3 \
  python3-pip \
  python3-dev \
  iw \
  wireless-tools \
  net-tools \
  iputils-ping \
  dnsutils \
  tcpdump \
  usbutils \
  pciutils

# Install aircrack-ng suite and related tools
RUN apt-get install -y \
  aircrack-ng \
  airgraph-ng \
  airgeddon \
  reaver \
  pixiewps \
  bully \
  hostapd \
  hostapd-wpe \
  dnsmasq \
  hcxtools \
  hcxdumptool \
  hashcat \
  john \
  john-data \
  crunch \
  wordlists

# Install wifite and dependencies
RUN apt-get install -y \
  wifite \
  tshark \
  pyrit \
  cowpatty

# Install additional WiFi security tools
RUN apt-get install -y \
  kismet \
  kismet-plugins \
  fern-wifi-cracker \
  wpscan \
  macchanger \
  ettercap-text-only \
  mdk3 \
  mdk4 \
  wireshark-common

# Install Python packages for WiFi security
RUN pip3 install --no-cache-dir \
  scapy \
  netaddr \
  requests \
  beautifulsoup4 \
  selenium \
  pwntools

# Create directories for labs and wordlists
RUN mkdir -p /opt/wordlists /opt/labs /opt/captures /opt/scripts

# Download common wordlists
RUN cd /opt/wordlists && \
  wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt && \
  wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/WiFi-WPA/probable-v2-wpa-top4800.txt

# Create useful scripts directory
COPY <<EOF /opt/scripts/setup-monitor.sh
#!/bin/bash
# Script to set up monitor mode
if [ \$# -eq 0 ]; then
    echo "Usage: \$0 <interface>"
    echo "Available interfaces:"
    iw dev | grep Interface | cut -d' ' -f2
    exit 1
fi

INTERFACE=\$1
echo "Setting up monitor mode on \$INTERFACE"
airmon-ng check kill
airmon-ng start \$INTERFACE
echo "Monitor mode setup complete"
EOF

COPY <<EOF /opt/scripts/quick-scan.sh
#!/bin/bash
# Quick WiFi network scan
if [ \$# -eq 0 ]; then
    echo "Usage: \$0 <monitor_interface>"
    exit 1
fi

INTERFACE=\$1
echo "Starting quick scan on \$INTERFACE"
echo "Press Ctrl+C to stop scanning"
airodump-ng \$INTERFACE
EOF

COPY <<EOF /opt/scripts/wifite-quick.sh
#!/bin/bash
# Quick wifite attack
if [ \$# -eq 0 ]; then
    echo "Usage: \$0 <interface>"
    exit 1
fi

INTERFACE=\$1
echo "Starting wifite on \$INTERFACE"
wifite --interface \$INTERFACE --crack --dict /opt/wordlists/rockyou.txt
EOF

# Make scripts executable
RUN chmod +x /opt/scripts/*.sh

# Set up aliases for convenience
RUN echo 'alias ll="ls -la"' >> /root/.bashrc && \
  echo 'alias la="ls -A"' >> /root/.bashrc && \
  echo 'alias l="ls -CF"' >> /root/.bashrc && \
  echo 'alias ..="cd .."' >> /root/.bashrc && \
  echo 'alias scan="airodump-ng"' >> /root/.bashrc && \
  echo 'alias crack="aircrack-ng"' >> /root/.bashrc && \
  echo 'alias monitor="/opt/scripts/setup-monitor.sh"' >> /root/.bashrc && \
  echo 'alias quickscan="/opt/scripts/quick-scan.sh"' >> /root/.bashrc && \
  echo 'export PATH="/opt/scripts:\$PATH"' >> /root/.bashrc

# Create a welcome message
RUN echo 'echo "=== WiFi Penetration Testing Lab ==="' >> /root/.bashrc && \
  echo 'echo "Available tools: aircrack-ng, wifite, reaver, kismet"' >> /root/.bashrc && \
  echo 'echo "Scripts: monitor <interface>, quickscan <interface>"' >> /root/.bashrc && \
  echo 'echo "Wordlists: /opt/wordlists/"' >> /root/.bashrc && \
  echo 'echo "Captures: /opt/captures/"' >> /root/.bashrc && \
  echo 'echo ""' >> /root/.bashrc

# Clean up
RUN apt-get autoremove -y && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /opt/labs

# Default command
CMD ["/bin/bash"]
