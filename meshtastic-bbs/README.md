# Meshtastic BBS

This project sets up a Meshtastic-based bulletin board system (BBS) on a Raspberry Pi with a LoRa hat.
It includes example configurations for `meshtasticd` and the BBS,
the Dockerfile for the container that will be running the TC2-BBS-mesh,
and service files for managing the dockerized BBS with `systemd`.

## Features

- Automates the installation of meshtasticd with an included `install.sh` script.
- Provides configurations for `meshtasticd`, the LoRa radio, and the BBS.
- Deploys the BBS in a Docker container with robust health monitoring.
- Includes a `systemd` service for automatic management with health-based restarts.
- Advanced healthcheck system that monitors both Meshtastic connectivity and process health.
- Automatic container recovery and restart capabilities.

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

3. Copy configuration files:

   **meshtasticd**

   ```bash
   mv /etc/meshtasticd/config.yaml /etc/meshtasticd/config.yaml.bak
   cp ./meshtasticd_config.yaml /etc/meshtasticd/config.yaml
   ```

   **BBS**

   ```bash
   mkdir -p /etc/TC2-BBS-mesh/config
   chown $USER:$USER /etc/TC2-BBS-mesh/config
   cp ./bbs_config.ini /etc/TC2-BBS-mesh/config/config.ini
   cp ./fortunes.txt /etc/TC2-BBS-mesh/config/fortunes.txt
   ```

   You can update the `hostname` in config.ini
   to be the IP address of your Raspberry Pi
   if the sockets library is throwing a connection error.

   **systemd services**

   ```bash
   cp ./mesh-bbs.service /etc/systemd/system/mesh-bbs.service
   cp ./mesh-bbs-healthcheck.service /etc/systemd/system/mesh-bbs-healthcheck.service
   cp ./mesh-bbs-healthcheck.timer /etc/systemd/system/mesh-bbs-healthcheck.timer
   systemctl daemon-reload
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

5. Enable the systemd services:

   ```bash
   # Enable and start the main BBS service
   sudo systemctl enable mesh-bbs.service
   sudo systemctl start mesh-bbs.service

   # Enable and start the health monitoring system
   sudo systemctl enable mesh-bbs-healthcheck.timer
   sudo systemctl start mesh-bbs-healthcheck.timer
   ```

## Health Monitoring System

The project includes a comprehensive health monitoring system to ensure reliable operation:

### Docker Health Check

The Docker container includes a built-in healthcheck that runs every 20 seconds and performs:

- **Meshtastic Connection Test**: Establishes a TCP connection to meshtasticd and tests bidirectional communication
- **Process Health Check**: Verifies the BBS server process is running and responsive
- **Multiple Retry Logic**: Attempts connection tests up to 3 times before failing

### systemd Health Monitoring

A systemd timer (`mesh-bbs-healthcheck.timer`) runs every 15 seconds to:

- Monitor the Docker container's health status
- Automatically restart the service if the container becomes unhealthy
- Handle cases where the container goes missing while the service is active
- Log all health check actions to the system journal

### Service Configuration

The main service (`mesh-bbs.service`) includes:

- Automatic restart on failure with exponential backoff
- Proper dependency management (requires meshtasticd and Docker)
- Container cleanup and image updates on startup
- Graceful shutdown handling

## Monitoring and Troubleshooting

### Check Service Status

```bash
# Main BBS service status
sudo systemctl status mesh-bbs.service

# Health check timer status
sudo systemctl status mesh-bbs-healthcheck.timer

# View recent health check runs
sudo systemctl list-timers mesh-bbs-healthcheck.timer
```

### View Logs

```bash
# Docker container logs
docker logs mesh-bbs

# systemd service logs
sudo journalctl -u mesh-bbs.service -f

# Health check logs
sudo journalctl -u mesh-bbs-healthcheck.service -f

# Combined logs for troubleshooting
sudo journalctl -u mesh-bbs.service -u mesh-bbs-healthcheck.service -f
```

### Manual Health Check

You can manually test the health check system:

```bash
# Check container health status
docker inspect --format='{{.State.Health.Status}}' mesh-bbs

# Run the health check script directly (if container is running)
docker exec mesh-bbs /usr/local/bin/healthcheck.py
```

### Common Issues and Solutions

**Container keeps restarting:**

- Check meshtasticd is running: `systemctl status meshtasticd.service`
- Verify LoRa hat connection and configuration
- Check Docker logs for specific error messages

**Health checks failing:**

- Ensure meshtasticd is accessible on port 4403
- Verify network connectivity between container and host
- Check system resources (CPU/memory usage)

**Service won't start:**

- Verify Docker is running: `systemctl status docker.service`
- Check that configuration files exist in `/etc/TC2-BBS-mesh/config/`
- Ensure proper file permissions on config directory

## Configuration Files

The project includes several configuration files:

- `meshtasticd_config.yaml` - Configuration for the Meshtastic daemon
- `bbs_config.ini` - BBS server configuration
- `fortunes.txt` - Fortune messages for the BBS
- `mesh-bbs.service` - Main systemd service definition
- `mesh-bbs-healthcheck.service` - Health check service
- `mesh-bbs-healthcheck.timer` - Health check timer configuration

## Acknowledgments

- [Meshtastic on Linux-Native](https://meshtastic.org/docs/hardware/devices/linux-native-hardware/)
- [TC2-BBS-mesh](https://github.com/TheCommsChannel/TC2-BBS-mesh)

## License

MIT
