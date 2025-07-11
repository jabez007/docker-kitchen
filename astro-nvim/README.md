# AstroNvim Docker Environment

This repository contains a Dockerfile to set up a development environment with AstroNvim and other commonly used tools.
It uses Docker volumes for persistent storage, ensuring fast startup times and consistent configurations across different machines.

## Features

- **Pre-installed tools** like Neovim, LazyGit, Bottom, and more.
- **Latest stable version of AstroNvim** configured out of the box.
- **Support for both** amd64 and arm64 architectures.
- **Non-root user** setup with bash as the default shell.
- **Persistent configuration** using Docker volumes for fast container restarts.
- **Smart plugin management** that installs plugins only on first run.

### Included Tools

The following tools and packages are installed:

| Tool    | Description                     |
| ------- | ------------------------------- |
| bash    | Default shell                   |
| curl    | Command-line file transfer tool |
| git     | Version control system          |
| lua     | Lua interpreter                 |
| nodejs  | JavaScript runtime              |
| npm     | Node.js package manager         |
| python3 | Python interpreter              |
| go      | Go programming language         |
| ripgrep | Fast search utility             |
| lazygit | Simple terminal UI for Git      |
| bottom  | System monitoring tool          |

## Build Arguments

The Dockerfile includes the following build arguments:

| Argument     | Description                                         | Default Value |
| ------------ | --------------------------------------------------- | ------------- |
| DEVUSER_NAME | Username for the non-root user inside the container | dev           |
| TARGETARCH   | Architecture of the Docker image (amd64 or arm64)   | Auto-detected |

These arguments can be passed during the build process using the --build-arg flag.

## Usage

### Option 1: Docker Compose (Recommended)

Create a `docker-compose.yml` file in your project directory:

```yaml
version: "3.8"

services:
  nvim-dev:
    build: .
    container_name: nvim-dev-container
    volumes:
      # Persist Neovim configuration and plugins
      - nvim-config:/home/dev/.config/nvim
      - nvim-share:/home/dev/.local/share/nvim
      - nvim-state:/home/dev/.local/state/nvim
      - nvim-cache:/home/dev/.cache/nvim

      # Mount your project directory
      - ./:/home/dev/workspace

    working_dir: /home/dev/workspace
    stdin_open: true
    tty: true
    environment:
      - TERM=xterm-256color

volumes:
  nvim-config:
  nvim-share:
  nvim-state:
  nvim-cache:
```

Then run:

```bash
# Start the container (first time will install plugins automatically)
docker-compose run --rm nvim-dev

# Or start in the background and attach
docker-compose up -d nvim-dev
docker-compose exec nvim-dev nvim
```

### Option 2: Direct Docker Usage

Build the image:

```bash
docker build -t astronvim-env .
```

Run with persistent volumes:

```bash
docker run --rm -it \
  -v nvim-config:/home/dev/.config/nvim \
  -v nvim-share:/home/dev/.local/share/nvim \
  -v nvim-state:/home/dev/.local/state/nvim \
  -v nvim-cache:/home/dev/.cache/nvim \
  -v $(pwd):/home/dev/workspace \
  -w /home/dev/workspace \
  astronvim-env
```

### First Run vs Subsequent Runs

- **First Run**: Takes ~30-60 seconds as plugins are installed automatically
- **Subsequent Runs**: Instant startup since plugins are cached in volumes
- **Plugin Updates**: Run `docker run --rm -it astronvim-env setup` to reinstall plugins

### Advanced Usage

#### Different Startup Modes

```bash
# Start Neovim normally
docker run --rm -it astronvim-env

# Open a specific file
docker run --rm -it astronvim-env myfile.txt

# Start bash shell instead of Neovim
docker run --rm -it astronvim-env bash

# Force plugin setup/reinstall
docker run --rm -it astronvim-env setup

# Clean plugins and cache
docker run --rm -it astronvim-env clean
```

#### Custom User Setup

Build with a specific non-root user:

```bash
docker build --build-arg DEVUSER_NAME=mydevuser -t astronvim-env .
```

Then adjust volume paths in your docker-compose.yml or run commands:

```bash
docker run --rm -it \
  -v nvim-config:/home/mydevuser/.config/nvim \
  -v nvim-share:/home/mydevuser/.local/share/nvim \
  -v $(pwd):/home/mydevuser/workspace \
  -w /home/mydevuser/workspace \
  astronvim-env
```

#### Multiple Projects

Use different volume sets for different projects:

```bash
# Project 1
docker run --rm -it \
  -v nvim-config-project1:/home/dev/.config/nvim \
  -v nvim-share-project1:/home/dev/.local/share/nvim \
  -v $(pwd)/project1:/home/dev/workspace \
  astronvim-env

# Project 2
docker run --rm -it \
  -v nvim-config-project2:/home/dev/.config/nvim \
  -v nvim-share-project2:/home/dev/.local/share/nvim \
  -v $(pwd)/project2:/home/dev/workspace \
  astronvim-env
```

## Volume Management

The container uses Docker volumes to persist:

- Neovim configuration (`~/.config/nvim`)
- Installed plugins (`~/.local/share/nvim`)
- Plugin state (`~/.local/state/nvim`)
- Cache files (`~/.cache/nvim`)

### Backup and Restore

```bash
# Backup configuration
docker run --rm -v nvim-config:/source -v $(pwd):/backup alpine tar czf /backup/nvim-config.tar.gz -C /source .

# Restore configuration
docker run --rm -v nvim-config:/target -v $(pwd):/backup alpine tar xzf /backup/nvim-config.tar.gz -C /target
```

### Clean Up

```bash
# Remove all volumes (fresh start)
docker volume rm nvim-config nvim-share nvim-state nvim-cache

# Or use docker-compose
docker-compose down -v
```

## Troubleshooting

### Plugin Installation Issues

```bash
# Clean and reinstall plugins
docker run --rm -it astronvim-env clean
docker run --rm -it astronvim-env setup
```

### Performance Issues

```bash
# Check volume disk usage
docker system df -v

# Clean unused volumes
docker volume prune
```

### Configuration Updates

If you update your AstroNvim configuration, run:

```bash
docker run --rm -it astronvim-env setup
```

## Local Installation (Alternative)

If you wish to install this on your local machine rather than run it as a Docker container, you can use the bash scripts:

```bash
# System-wide installation (requires sudo)
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/astro-nvim/install.sh | sudo bash

# User-level configuration
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/astro-nvim/setup.sh | bash
```

## Contributing

Feel free to fork this repository and submit pull requests if you have improvements or suggestions.

## License

This project is licensed under the MIT License.
