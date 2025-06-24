#!/bin/bash

set -euo pipefail

debug=false
system_wide=false

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
    --debug | -d)
        debug=true
        shift
        ;;
    --system-wide | -s)
        system_wide=true
        shift
        ;;
    *)
        printf "Unknown option: %s\n" "$1" >&2
        exit 1
        ;;
    esac
done

# Enable debugging if --debug or -d is passed
if $debug; then
    set -x
fi

# Function to install dependencies
install_dependencies() {
    apt-get update && apt-get install -y --no-install-recommends \
        bash \
        curl \
        git \
        lua5.1 \
        python3 \
        ripgrep \
        unzip \
        build-essential \
        ca-certificates \
        libssl-dev \
        libffi-dev \
        openssh-client

    local python_version
    python_version=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2)
    local venv_to_install
    venv_to_install="python${python_version}-venv"
    apt-get install -y --no-install-recommends \
        "$venv_to_install"
}

# Helper function to trim leading and trailing whitespace
trim() {
    local input="$1"
    printf "%s" "$input" | awk '{$1=$1};1'
}

# Function to persist PATH changes
persist_path_update() {
    local path_entry="$1"
    local shell_config

    if $system_wide; then
        # Use system-wide configuration files
        if [[ -n "${ZSH_VERSION-}" ]]; then
            shell_config="/etc/zsh/zshrc"
        else
            shell_config="/etc/bash.bashrc"
        fi
    else
        # Use user-specific configuration files
        if [[ -n "${SUDO_USER-}" ]]; then
            shell_config="/home/$SUDO_USER/.bashrc"
            if [[ -n "${ZSH_VERSION-}" ]]; then
                shell_config="/home/$SUDO_USER/.zshrc"
            fi
        else
            shell_config="${HOME}/.bashrc"
            if [[ -n "${ZSH_VERSION-}" ]]; then
                shell_config="${HOME}/.zshrc"
            fi
        fi
    fi

    # Append the PATH update if not already present
    if ! grep -qxF "export PATH=\"\$PATH:${path_entry}\"" "$shell_config"; then
        printf "\n# Add Go to PATH\nexport PATH=\"\$PATH:${path_entry}\"\n" >>"$shell_config"
        printf "Updated PATH in %s\n" "$shell_config"
    fi
}

install_go() {
    local go_url
    go_url=$(curl -fsSL "https://go.dev/VERSION?m=text" | grep "^go" |
        awk -v arch="$(dpkg --print-architecture)" '{printf "https://go.dev/dl/%s.linux-%s.tar.gz", $1, arch}')
    go_url=$(trim "$go_url")
    printf "Resolved Go URL: %s\n" "$go_url"
    curl -L "$go_url" -o go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz

    # Set location of go executable
    local go_bin="/usr/local/go/bin"

    # Update PATH for the current session
    export PATH="$PATH:$go_bin"

    # Persist PATH
    persist_path_update "$go_bin"
}

install_lazygit() {
    local lazygit_url
    printf "Fetching LazyGit latest release information...\n"
    lazygit_url=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
        grep "browser_download_url.*lazygit.*$(uname -s).*$(uname -m).*tar.gz" |
        cut -d : -f 2,3 | tr -d \" | tail -n 1)
    lazygit_url=$(trim "$lazygit_url")

    if [[ -z "$lazygit_url" ]]; then
        printf "Error: LazyGit download URL could not be resolved.\n" >&2
        return 1
    fi

    printf "Resolved LazyGit URL: %s\n" "$lazygit_url"
    curl -L "$lazygit_url" -o lazygit.tar.gz
    tar -C /usr/local/bin -xzf lazygit.tar.gz
    rm lazygit.tar.gz
}

install_bottom() {
    local bottom_url
    printf "Fetching Bottom latest release information...\n"
    bottom_url=$(curl -s https://api.github.com/repos/ClementTsang/bottom/releases/latest |
        grep "browser_download_url.*bottom.*$(dpkg --print-architecture).*deb" |
        cut -d : -f 2,3 | tr -d \" | tail -n 1)
    bottom_url=$(trim "$bottom_url")

    if [[ -z "$bottom_url" ]]; then
        printf "Error: Bottom download URL could not be resolved.\n" >&2
        return 1
    fi

    printf "Resolved Bottom URL: %s\n" "$bottom_url"
    curl -L "$bottom_url" -o bottom.deb
    dpkg -i bottom.deb
    rm bottom.deb
}

install_neovim() {
    local arch
    arch=$(dpkg --print-architecture)
    local nvim_tarball

    if [[ "$arch" == "arm64" ]]; then
        nvim_tarball="nvim-linux-arm64"
    else
        nvim_tarball="nvim-linux-x86_64"
    fi

    printf "Fetching Neovim latest stable release...\n"
    curl -LO "https://github.com/neovim/neovim/releases/download/stable/${nvim_tarball}.tar.gz"
    rm -rf /opt/nvim*
    tar -C /opt -xzf "${nvim_tarball}.tar.gz"
    rm "${nvim_tarball}.tar.gz"
    # Create or update the symbolic link
    if [[ -L /usr/local/bin/nvim ]]; then
        printf "Symbolic link '/usr/local/bin/nvim' already exists. Overwriting...\n"
    fi
    ln -sf "/opt/${nvim_tarball}/bin/nvim" /usr/local/bin/nvim
}

main() {
    printf "Installing dependencies...\n"
    install_dependencies || {
        printf "Failed to install dependencies.\n" >&2
        exit 1
    }

    printf "Installing Go...\n"
    install_go || {
        printf "Failed to install Go.\n" >&2
        exit 1
    }

    printf "Installing LazyGit...\n"
    install_lazygit || {
        printf "Failed to install LazyGit.\n" >&2
        exit 1
    }

    printf "Installing Bottom...\n"
    install_bottom || {
        printf "Failed to install Bottom.\n" >&2
        exit 1
    }

    printf "Installing Neovim...\n"
    install_neovim || {
        printf "Failed to install Neovim.\n" >&2
        exit 1
    }

    printf "All tools installed successfully.\n"
}

main "$@"
