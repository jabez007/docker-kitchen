# Docker Kitchen

Docker Kitchen is a collection of Dockerfiles and related resources to build and use various Docker images.

## Repository Structure

Each Docker image has its own sub-directory containing:

- A `Dockerfile` for building the image
- Supporting scripts and files as needed

## Installation and Usage Examples

This repo also includes a comprehensive setup script for building and configuring development environments on Linux systems, VMs, and Docker containers.

### Modular Installation Script

The install.sh script is a powerful, modular tool that can set up complete development environments or install specific components as needed.
It automatically detects your system (regular Linux, Docker container, or root environment) and adapts accordingly.

#### Quick Start

##### Install Everything

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- all
```

##### Install Specific Component

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- base go editor
```

**Available Components**
| Component | Description |
|-----------|-------------|
| `base` | Base dependencies (curl, git, build tools, ripgrep, etc.) |
| `go` | Go programming language (latest version) |
| `node` | Node.js stack (NVM, Node.js LTS, Deno) |
| `editor` | Editor stack (Neovim, LazyGit, Bottom system monitor) |
| `config` | User configurations (AstroNvim configuration) |
| `shell` | Shell stack (Fish shell, Tmux, Starship prompt) |
| `docker` | Docker and Docker Compose |
| `all` | Install all components |

#### Usage Examples

##### Basic Development Setup

```bash
# Minimal setup for coding
./install.sh base go editor config

# Full development environment
./install.sh all
```

##### Docker Container Setup

```bash
# Lightweight container setup
./install.sh base editor config

# Container with specific language support
./install.sh base go node editor config
```

##### VM/Server Setup

```bash
# Complete development server
./install.sh --debug all

# Shell-focused setup
./install.sh base shell config
```

#### Advanced Options

```bash
# Enable debug output
./install.sh --debug base go editor

# Install system-wide where applicable
./install.sh --system-wide base

# Customize tmux session name
./install.sh --tmux-session "dev" shell

# Use different Starship preset
./install.sh --starship-preset "pure-preset" shell

# Use custom AstroNvim configuration
./install.sh --astronvim-repo "https://github.com/your-user/astronvim-config.git" config
```

#### Configuration File

The script supports configuration files for consistent setups across multiple environments:

```bash
# Create a configuration file
./install.sh --save-config
```

#### Key Features

- **Environment Detection**: Automatically detects Docker containers, root environments, and regular user setups
- **User Preservation**: When run with sudo, installs user configs to the original user's home directory
- **Package Manager Agnostic**: Supports apt, dnf, yum, brew, and pacman
- **Modular Design**: Install only what you need
- **Comprehensive Logging**: Detailed logs saved to `setup.log`
- **Fish Shell Integration**: Automatic NVM setup, tmux integration, and Starship prompt

#### What Gets Installed

##### Base Component

- Essential build tools and libraries
- Git, curl, unzip, ripgrep
- Python 3 and Lua
- SSL certificates and SSH client

##### Go Component

- Latest Go version from official releases
- Proper PATH configuration
- Cross-platform architecture detection

##### Node Component

- NVM (Node Version Manager)
- Node.js LTS
- Deno runtime
- Fish shell NVM integration

##### Editor Component

- Neovim (latest stable)
- LazyGit (Git TUI)
- Bottom (system monitor)

##### Config Component

- AstroNvim configuration
- Customizable via `--astronvim-repo` option

##### Shell Component

- Fish shell with smart configuration
- Tmux with TPM (Tmux Plugin Manager)
- Starship prompt with customizable presets
- Automatic tmux session management
- Bash-to-Fish integration

##### Docker Component

- Docker CE and Docker Compose
- Proper user group configuration
- Platform-specific installation

#### Docker Integration

The script is designed to work seamlessly in Docker containers:

```dockerfile
# Example Dockerfile usage
FROM ubuntu:22.04

# Install development environment
RUN curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- base go editor config

# Set Fish as default shell
SHELL ["fish", "-c"]
```

#### Logging and Troubleshooting

- All operations are logged to `setup.log` in the script directory
- Use `--debug` flag for verbose output
- Each component can be installed independently for troubleshooting
- The script is idempotent - safe to run multiple times

#### System Requirements

- Linux-based system (Ubuntu, Debian, Fedora, CentOS, Arch Linux)
- macOS (limited support via Homebrew)
- Bash 4.0+ or compatible shell
- Internet connection for downloading packages

### Install NerdFont for AstroNvim and Starship

You can download and install a NerdFont zip file from the repository using the following command:

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/astro-nvim/Mononoki.zip -o Mononoki.zip && \
unzip Mononoki.zip -d ~/.fonts && \
fc-cache -fv
```

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.

## License

This repository is licensed under the MIT License. See the `LICENSE` file for more details.
