# WiFi Penetration Testing Lab Environment
FROM kalilinux/kali-rolling:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color

# Update package lists and install base tools
RUN apt-get update\
  # Install core system utilities
  && apt-get install -y \
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
  #python3-pip \
  python3-dev \
  pipx \
  iw \
  wireless-tools \
  net-tools \
  iputils-ping \
  dnsutils \
  tcpdump \
  usbutils \
  pciutils \
  # Install aircrack-ng suite and related tools
  && apt-get install -y \
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
  wordlists \
  # Install wifite and dependencies
  && apt-get install -y \
  wifite \
  tshark \
  #pyrit \
  cowpatty \
  # Install additional WiFi security tools
  && apt-get install -y \
  kismet \
  kismet-plugins \
  fern-wifi-cracker \
  wpscan \
  macchanger \
  ettercap-text-only \
  mdk3 \
  mdk4 \
  wireshark-common \
  # Install Python packages via apt where available
  && apt-get install -y \
  python3-scapy \
  python3-netaddr \
  python3-requests \
  python3-bs4 \
  python3-selenium \
  # 
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python applications via pipx
RUN pipx install pwntools

# Create directories for labs and wordlists
RUN mkdir -p /opt/wordlists /opt/labs /opt/captures /opt/scripts

# Download common wordlists
RUN cd /opt/wordlists && \
  wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt && \
  wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/WiFi-WPA/probable-v2-wpa-top4800.txt

# Copy scripts and make them executable
COPY scripts/ /opt/scripts/
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
