# LPIC-1 Docker Study Environment

This repository contains a Docker-based study environment for LPIC-1 certification preparation.
Instead of using a traditional VM, this environment provides a lightweight, reproducible Linux container with all the necessary tools to practice for the LPIC-1 exam.

## Features

- Based on Ubuntu LTS
- Includes all essential tools and packages required for LPIC-1 exam topics
- Pre-configured user account with sudo privileges
- Persistent home directory via Docker volumes
- Support for systemd (with special run configuration)
- Easy to extend for specific study areas

## Getting Started

### Prerequisites

- Docker installed on your system
- Basic familiarity with Docker commands

### Building the Image

```bash
# Clone this repository
git clone https://github.com/jabez007/docker-kitchen.git
cd docker-kitchen/lpic-labs

# Build the Docker image with a secure password for the student user
docker build --build-arg STUDENT_PASSWORD=your_secure_password -t lpic1-practice .
```

**Important**: Replace `your_secure_password` with a strong password of your choice. This password will be used for the `student` user account.

### Running the Container

#### Basic Usage

```bash
# Run with a Docker-managed volume for persistence
docker run -it --name lpic1 lpic1-practice
```

#### With Host Directory Mounted

```bash
# Create a directory on your host for persistence
mkdir -p ~/lpic1-files

# Run with the host directory mounted
docker run -it --name lpic1 -v ~/lpic1-files:/home/student lpic1-practice
```

#### For systemd Support

```bash
# Run with systemd support
docker run -d --name lpic1-systemd --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro lpic1-practice /sbin/init

# Connect to the running container
docker exec -it lpic1-systemd bash
```

### Stopping and Restarting

```bash
# Stop the container
docker stop lpic1

# Start it again
docker start -i lpic1
```

## Study Environment Details

### User Account

- Username: `student`
- Password: The password you specified during the build process with `--build-arg STUDENT_PASSWORD=your_password`
- Sudo access: Yes (passwordless)

### Installed Packages

The environment includes tools for all major LPIC-1 exam objectives:

- **System Architecture**: `procps`, `psmisc`, `systemd`
- **Linux Installation and Package Management**: `apt`, `dpkg`
- **GNU and Unix Commands**: `find`, `grep`, `sed`, `awk`, `tar`, etc.
- **Devices, Linux Filesystems, FHS**: `fdisk`, `parted`, `lvm2`, `e2fsprogs`, etc.
- **Shells and Shell Scripting**: `bash`
- **User Interfaces and Desktops**: (minimal)
- **Administrative Tasks**: `cron`, `at`, `rsyslog`
- **Essential System Services**: `systemd`, `ssh`
- **Networking Fundamentals**: `net-tools`, `iproute2`, `dnsutils`
- **Security**: `sudo`, `passwd`, `ssh`

## Extending for Specific Topics

### Additional Storage for Filesystem Practice

```bash
# Create additional volumes for storage management practice
docker run -it --name lpic1 \
  -v ~/lpic1-files:/home/student \
  -v ~/lpic1-disk1:/mnt/disk1 \
  -v ~/lpic1-disk2:/mnt/disk2 \
  lpic1-practice
```

### Network Configuration Practice

```bash
# Run with host networking for network configuration practice
docker run -it --name lpic1 --network host -v ~/lpic1-files:/home/student lpic1-practice
```

## LPIC-1 Study Tips

1. Create a study schedule covering all exam objectives
2. Practice commands repeatedly until comfortable
3. Create scripts to automate tasks as practice
4. Review the official LPI exam objectives regularly
5. Try to break and fix various system components
6. Practice disk partitioning and filesystem management
7. Work with different runlevels and boot processes

## Exam Topics Coverage

This Docker environment is suitable for practicing most LPIC-1 topics, including:

- System Architecture
- Linux Installation and Package Management
- GNU and Unix Commands
- Devices, Linux Filesystems, Filesystem Hierarchy Standard
- Shells and Shell Scripting
- User Interfaces and Desktops (limited)
- Administrative Tasks
- Essential System Services
- Networking Fundamentals
- Security

## License

This project is released under the MIT License. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Linux Professional Institute for the LPIC certification program
- Docker for the containerization technology
