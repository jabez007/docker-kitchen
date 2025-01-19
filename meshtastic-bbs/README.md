# Meshtastic BBS

This project sets up a Meshtastic-based bulletin board system (BBS) on a Raspberry Pi with a LoRa hat. It includes tools for configuring `meshtasticd`, setting up a Docker container for the TC2-BBS-mesh system, and managing the system with `systemd`.

## Features

- Automates the installation of meshtasticd with an included `install.sh` script.
- Provides configurations for `meshtasticd`, the LoRa radio, and the BBS.
- Deploys the BBS in a Docker container.
- Includes a secure `systemd` service for automatic management.

## Prerequisites

- A Raspberry Pi with a LoRa hat.
  - [MeshAdv Pi Hat](https://www.etsy.com/listing/1849074257/meshadv-pi-hat-v11-fully-assembled-1)
- Raspberry Pi OS (any version based on Debian Bookworm).
- Internet access for downloading dependencies.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/jabez007/docker-kitchen.git
   cd docker-kitchen/meshtastic-bbs
   ```

2. Run the installation script:

   ```bash
   sudo ./install.sh
   ```

   or, without cloning the repo

   ```bash
   curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/meshtastic-bbs/install.sh | bash
   ```

3. Copy config:

   Meshtasticd

   ```bash
   mv /etc/meshtasticd/config.yaml /etc/meshtasticd/config.yaml.bak
   cp ./meshtasticd_config.yaml /etc/meshtasticd/config.yaml
   ```

   BBS

   ```bash
   mkdir -p /etc/TC2-BBS-mesh/config
   cp ./bbs_config.ini /etc/TC2-BBS-mesh/config/config.ini
   ```

4. Build and start the Docker container:

   ```bash
   docker build -t meshtastic-bbs .
   docker run --name meshtastic-bbs meshtastic-bbs
   ```

5. Enable the systemd service:
   ```bash
   sudo systemctl enable meshtastic-bbs.service
   sudo systemctl start meshtastic-bbs.service
   ```

## Troubleshooting

- Check Docker logs:
  ```bash
  docker logs meshtastic-bbs
  ```
- Verify `systemd` status:
  ```bash
  systemctl status meshtastic-bbs.service
  ```

## Acknowledgments

- [Meshtastic on Linux-Native](https://meshtastic.org/docs/hardware/devices/linux-native-hardware/)
- [TC2-BBS-mesh](https://github.com/TheCommsChannel/TC2-BBS-mesh)

## License

MIT
