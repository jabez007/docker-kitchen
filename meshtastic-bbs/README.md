# Meshtastic BBS

This project sets up a Meshtastic-based bulletin board system (BBS) on a Raspberry Pi with a LoRa hat.
It includes example configurations for `meshtasticd` and the BBS,
the Dockerfile for the container that will be running the TC2-BBS-mesh,
and a service file managing the dockerized BBS with `systemd`.

## Features

- Automates the installation of meshtasticd with an included `install.sh` script.
- Provides configurations for `meshtasticd`, the LoRa radio, and the BBS.
- Deploys the BBS in a Docker container.
- Includes a `systemd` service for automatic management.

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

   meshtasticd

   ```bash
   mv /etc/meshtasticd/config.yaml /etc/meshtasticd/config.yaml.bak
   cp ./meshtasticd_config.yaml /etc/meshtasticd/config.yaml
   ```

   BBS

   ```bash
   mkdir -p /etc/TC2-BBS-mesh/config
   chown $USER:$USER /etc/TC2-BBS-mesh/config
   cp ./bbs_config.ini /etc/TC2-BBS-mesh/config/config.ini
   cp ./fortunes.txt /etc/TC2-BBS-mesh/config/fortunes.txt
   ```

   You can update the `hostname` in config.ini
   to be the IP address of your Raspberry Pi
   if the sockets library is throwing a connection error.

   systemd

   ```bash
   cp ./mesh-bbs.service /etc/systemd/system/mesh-bbs.service
   ```

4. Configure Meshtastic:

   The meshtasticd config in the previous step
   basically just tells the Raspberry Pi how to interface with your specific LoRa hat.
   Now we have to configure the Meshtastic software
   same as if we had just turned on a WisBlock4361 for the first time.
   Luckily, this can be done using the phone app
   if your Raspberry Pi is connected to your network (ethernet or wifi).
   You just need to find the IP address of your Raspberry Pi
   (if you aren't already SSHed in to your Raspberry Pi).

   ```bash
   ip address show eth0 | awk '/inet (\S*)/ {print $2}' | grep -oP "(\d+\.){3}\d+"
   ```

   or

   ```bash
   ip address show wlan0 | awk '/inet (\S*)/ {print $2}' | grep -oP "(\d+\.){3}\d+"
   ```

   If you are feeling venturous
   and want to use the command line to configure Meshtastic,
   the install script has an option to include the Python CLI.
   Then using the Python CLI you would run commands such as:

   To set the region

   ```bash
   meshtastic --set lora.region=US
   ```

   To set the radio's name

   ```bash
   meshtastic --set-owner "Meshtastic BBS"
   meshtastic --set-owner-short "\u2709"
   ```

   [Python CLI reference](https://meshtastic.org/docs/software/python/cli/)

5. Enable the systemd service:
   ```bash
   sudo systemctl enable mesh-bbs.service
   sudo systemctl start mesh-bbs.service
   ```

## Troubleshooting

- Check Docker logs:
  ```bash
  docker logs mesh-bbs
  ```
- Verify `systemd` status:
  ```bash
  systemctl status mesh-bbs.service
  ```

## Acknowledgments

- [Meshtastic on Linux-Native](https://meshtastic.org/docs/hardware/devices/linux-native-hardware/)
- [TC2-BBS-mesh](https://github.com/TheCommsChannel/TC2-BBS-mesh)

## License

MIT
