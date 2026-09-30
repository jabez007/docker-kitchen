# Docker Kitchen

Docker Kitchen is a collection of Dockerfiles and related resources to build and use various Docker images.

## Repository Structure

Each Docker image has its own sub-directory containing:

- A `Dockerfile` for building the image
- Supporting scripts and files as needed

## Installation and Usage Examples

This repo also includes a comprehensive setup script for building and configuring development environments on Linux systems, VMs, and Docker containers.

### Modular Installation Script

`install.sh` sets up a development environment one component at a time.
It picks the package manager it finds, uses `sudo` only when it isn't already root, and writes user configs to the invoking user's home even under `sudo`.
When piped from `curl`, it downloads the modules it needs from this repo into a temp directory.

#### Quick Start

##### Install Everything

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- all
```

##### Install Specific Component

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- base go editor
```

##### Install from another branch

A piped `install.sh` can't tell which URL it came from, so it downloads its modules from `master` unless `GITHUB_BRANCH` says otherwise.
Set it to the same branch (or a commit SHA) as the URL:

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/BRANCH/install.sh | GITHUB_BRANCH=BRANCH bash -s -- all
```

**Available Components**
| Component | Description |
|-----------|-------------|
| `base` | Base dependencies (curl, git, build tools, ripgrep, etc.) |
| `shell` | Shell stack (Fish shell, Tmux, Starship prompt, Atuin shell history) |
| `go` | Go programming language (latest version) |
| `node` | Node.js stack (NVM, Node.js LTS, Deno) |
| `python` | pyenv plus the headers needed to build Python |
| `editor` | Editor stack (Neovim, LazyGit, Bottom system monitor) |
| `docker` | Docker and Docker Compose |
| `config` | User configurations (Git settings, AstroNvim configuration) |
| `font` | A Nerd Font for your terminal (Mononoki unless you pick another) |
| `all` | Install all components except `font` |

Components always run in the order above, whatever order you list them in, so `config` sees the Neovim that `editor` installed.
`all` leaves out `font`, because a font only helps on the machine that runs your terminal. Over SSH or in a container, that's a different machine.

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

# Install a different Nerd Font (names as on https://www.nerdfonts.com/font-downloads)
./install.sh --nerd-font JetBrainsMono font

# Set git identity (only applied if not already configured)
./install.sh --git-name "Your Name" --git-email "you@example.com" config

# Upgrade tools that are already installed
./install.sh --upgrade go node editor
```

#### Configuration File

`install.sh` reads `setup.conf` from its own directory.
`--config FILE` reads a different file instead, as the astro-nvim image does with `astro-nvim/setup.conf`.

The file is sourced as shell code, so only use one you trust.
For that reason, a run piped from `curl` doesn't look for `setup.conf` in the current directory; pass `--config` to use one.

`--save-config` writes the defaults plus any other options on the same command line:

```bash
./install.sh --starship-preset pure-preset --git-name "Your Name" --save-config

# Piped runs need to be told where to save and read it
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- --config ./setup.conf --save-config
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- --config ./setup.conf all
```

Supported keys: `SYSTEM_WIDE`, `UPGRADE`, `KEEP_GIT`, `TMUX_SESSION`, `STARSHIP_PRESET`, `ASTRONVIM_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `NERD_FONT`, `LOG_LEVEL`.

#### Upgrading

Without `--upgrade`, a re-run skips anything that is already installed.
With it, each component brings its tools up to date:

- Go, Neovim, LazyGit, Bottom, Starship, Atuin, NVM, Node.js, Deno and the Nerd Font compare the installed version with the latest release and reinstall only when they differ.
- Node.js moves to the latest LTS and carries global npm packages over. The old version stays installed; remove it with `nvm uninstall <version>`.
- pyenv and pyenv-virtualenv move to their latest release tags.
  An older run may have installed the pyenv-update plugin; `pyenv update` fails on a tag, so use `install.sh --upgrade python` instead.
- Fisher moves to its latest release, and `fisher update` updates the other Fish plugins.
- TPM and the AstroNvim config update themselves with `git pull`.
  The AstroNvim config only updates if it was cloned with `KEEP_GIT=true`.
- System packages (base, shell, docker and so on) upgrade through the package manager.
- An existing `starship.toml` is never overwritten. Delete it to apply a new preset.

#### Key Features

- Runs as a normal user (using `sudo` where needed) or as root
- Under `sudo`, user configs go to the original user's home and are owned by them
- Supports apt, dnf, yum, brew, and pacman
- Stops at the first failed command and reports the file and line
- Checks each download against a SHA-256 and stops on a mismatch.
  Go, LazyGit, Starship, Atuin, Deno and Nerd Fonts publish their own checksums.
  Neovim and Bottom don't, so the script uses the digest GitHub computes when a release asset is uploaded.
  That catches a corrupted or altered download, but not a bad file that was uploaded to the release itself.
- Installs NVM, pyenv, Fisher and bash-preexec from their latest release tags, so a change on an upstream default branch doesn't reach you until it's released.
  None of them publish checksums, so a tag that moves after release would go unnoticed.
- Logs to `setup.log`
- Fish gets NVM (via bass), pyenv, tmux auto-attach, and Starship

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

##### Python Component

- pyenv and pyenv-virtualenv, configured for Bash and Fish
- Build dependencies for compiling Python (run `pyenv install 3` afterwards)

##### Editor Component

- Neovim (latest stable)
- LazyGit (Git TUI)
- Bottom (system monitor)

##### Config Component

- Git defaults and aliases, plus `user.name`/`user.email` from `--git-name`/`--git-email`
- AstroNvim configuration (skipped if Neovim isn't installed)
- Customizable via `--astronvim-repo` option

##### Shell Component

- Fish shell with smart configuration
- Tmux with TPM (Tmux Plugin Manager)
- Starship prompt with customizable presets
- Automatic tmux session management
- [Atuin](https://atuin.sh) shell history for Fish and Bash.
  It keeps each command's directory, exit code and duration, and Ctrl+R and the up arrow open its full-screen search.
  Bash gets the hooks Atuin needs from [bash-preexec](https://github.com/rcaloras/bash-preexec), saved as `~/.bash-preexec.sh`.
  The first install imports your existing Bash and Fish history.
  The script never logs in for sync. Run `atuin register` or `atuin login` yourself if you want it.
- Bash-to-Fish integration.
  An interactive Bash switches to Fish at the end of `~/.bashrc`, so nothing below that block runs.
  Each run of `install.sh` moves the block back to the end, below anything added since.
  `bash -c` and `bash -i -c` stay in Bash.

##### Font Component

- A [Nerd Font](https://www.nerdfonts.com), which AstroNvim and the Starship presets need for their icons.
  Without one, the prompt and the Neovim file tree show empty boxes.
- The font goes in `~/.local/share/fonts/<name>`, or `/usr/local/share/fonts/<name>` with `--system-wide`, and `fc-cache` picks it up.
  The script installs `fontconfig` if `fc-cache` is missing.
- On macOS it installs the Homebrew cask `font-<name>-nerd-font` instead.
- Afterwards, pick the font in your terminal's settings. For Mononoki it's called "Mononoki Nerd Font".

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
RUN apt-get update && apt-get install -y curl && \
  curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- base shell go editor config

# Set Fish as default shell
SHELL ["fish", "-c"]
```

#### Logging and Troubleshooting

- All operations are logged to `setup.log` in the script directory
- Use `--debug` flag for verbose output
- Each component can be installed independently for troubleshooting
- Re-running skips tools that are already installed (use `--upgrade` to update them)

#### System Requirements

- Linux-based system (Ubuntu, Debian, Fedora, CentOS, Arch Linux)
- macOS (limited support via Homebrew)
- Bash 4.0+ or compatible shell
- Internet connection for downloading packages

### Install a Nerd Font for AstroNvim and Starship

Run the `font` component on the machine that runs your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- font
```

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.

## License

This repository is licensed under the MIT License. See the `LICENSE` file for more details.
