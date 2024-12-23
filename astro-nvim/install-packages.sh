#!/bin/bash

set -euo pipefail

# Enable command tracing for debugging
set -x

install_go() {
    local go_url
    go_url=$(curl -fsSL "https://go.dev/VERSION?m=text" | grep "^go" | \
        awk -v arch="$(dpkg --print-architecture)" '{printf "https://go.dev/dl/%s.linux-%s.tar.gz", $1, arch}')
    printf "Resolved Go URL: %s\n" "$go_url"
    curl -L "$go_url" -o go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz

    # Update PATH for current session
    export PATH="$PATH:/usr/local/go/bin"

    # Persist PATH modification
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        printf '\n# Add Go to PATH\nexport PATH="$PATH:/usr/local/go/bin"\n' >> ~/.bashrc
    fi
}

install_lazygit() {
    local lazygit_url
    printf "Fetching LazyGit latest release information...\n"
    lazygit_url=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | \
        grep "browser_download_url.*lazygit.*$(uname -s).*$(uname -m).*tar.gz" | \
        cut -d : -f 2,3 | tr -d \" | tail -n 1)

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
    bottom_url=$(curl -s https://api.github.com/repos/ClementTsang/bottom/releases/latest | \
        grep "browser_download_url.*bottom.*$(dpkg --print-architecture).*deb" | \
        cut -d : -f 2,3 | tr -d \" | tail -n 1)

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
    printf "Fetching Neovim latest stable release...\n"
    curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
    rm -rf /opt/nvim*
    tar -C /opt -xzf nvim-linux64.tar.gz
    rm nvim-linux64.tar.gz
    ln -s /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
}

main() {
    printf "Installing Go...\n"
    install_go || { printf "Failed to install Go.\n" >&2; exit 1; }

    printf "Installing LazyGit...\n"
    install_lazygit || { printf "Failed to install LazyGit.\n" >&2; exit 1; }

    printf "Installing Bottom...\n"
    install_bottom || { printf "Failed to install Bottom.\n" >&2; exit 1; }

    printf "Installing Neovim...\n"
    install_neovim || { printf "Failed to install Neovim.\n" >&2; exit 1; }

    printf "All tools installed successfully.\n"
}

main "$@"
