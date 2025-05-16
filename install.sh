#!/bin/bash

# Script to install tmux and fish, configure fish to attach or create a tmux session,
# and update .bashrc to launch fish automatically while keeping bash as the default shell.

set -euo pipefail

# Define constants
TMUX_SESSION="default"
FISH_CONFIG="$HOME/.config/fish/config.fish"
BASHRC="$HOME/.bashrc"
TMUX_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TMUX_RESURRECT="tmux-plugins/tmux-resurrect"

# Flag for Docker installation
INSTALL_DOCKER=""
# 
STARSHIP_PRESET="gruvbox-rainbow"

# Function to parse arguments
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --install-docker)
                INSTALL_DOCKER=true
                ;;
            --skip-docker)
                INSTALL_DOCKER=false
                ;;
            --starship-preset=*)
                STARSHIP_PRESET="${arg#*=}"
                ;;
            --help|-h)
                printf "Usage: %s [OPTIONS]\n\n" "$(basename "$0")"
                printf "Options:\n"
                printf "  --install-docker    Install Docker without prompting\n"
                printf "  --skip-docker       Skip Docker installation without prompting\n"
                printf "  --starship-preset=NAME     Apply specific Starship preset (default: gruvbox-rainbow)\n"
                printf "  -h, --help          Display this help message\n"
                exit 0
                ;;
            *)
                printf "Unknown option: %s\n" "$arg" >&2
                printf "Use --help for usage information.\n"
                exit 1
                ;;
        esac
    done
}

# Function to install dependencies
install_dependencies() {
    printf "Installing tmux and fish...\n"
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y tmux fish git
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y tmux fish git
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y tmux fish git
    elif command -v brew >/dev/null 2>&1; then
        brew install tmux fish git
    else
        printf "Unsupported package manager. Install tmux and fish manually.\n" >&2
        return 1
    fi
}

# Function to install Docker for Ubuntu or Fedora with post-installation steps
install_docker() {
    printf "Installing Docker...\n"

    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        printf "Docker is already installed. Skipping installation.\n"
        return
    fi

    # Detect the operating system and run the corresponding steps
    if command -v apt >/dev/null 2>&1; then
        printf "Detected Ubuntu-based system. Installing Docker...\n"

        # Ubuntu installation steps
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        printf "Docker installation complete on Ubuntu.\n"

    elif command -v dnf >/dev/null 2>&1; then
        printf "Detected Fedora-based system. Installing Docker...\n"

        # Fedora installation steps
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker

        printf "Docker installation complete on Fedora.\n"

    elif command -v yum >/dev/null 2>&1; then
        printf "Detected RPM-based system. Installing Docker...\n"

        # RPM installation steps
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker

        printf "Docker installation complete on RPM.\n"

    elif command -v brew >/dev/null 2>&1; then
        printf "Detected Homebrew package manager. Installing Docker...\n"

        brew install --cask docker

        printf "Docker installation complete thru Homebrew.\n"

    else
        printf "Unsupported operating system. Please install Docker manually.\n" >&2
        return 1
    fi

    # Post-installation steps
    printf "Performing Docker post-installation steps...\n"

    # Create the docker group if it doesn't exist
    if ! getent group docker >/dev/null; then
        sudo groupadd docker
        printf "Docker group created.\n"
    else
        printf "Docker group already exists.\n"
    fi

    # Add the current user to the docker group
    sudo usermod -aG docker "$USER"
    printf "Added user '%s' to the 'docker' group.\n" "$USER"

    # Notify the user about restarting the session
    printf "\nTo apply the changes, restart your terminal session or run:\n"
    printf "  exec sg docker -c \"$(basename "$SHELL")\"\n"
    printf "\nDocker installation and configuration complete.\n"
}

# Function to install tmux-resurrect via TPM
install_tmux_resurrect() {
    printf "Installing tmux-resurrect...\n"

    # Install TPM if not already installed
    if [[ ! -d "$TPM_DIR" ]]; then
        printf "Cloning TPM (Tmux Plugin Manager)...\n"
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    fi

    # Add tmux-resurrect to .tmux.conf if not already present
    if ! grep -q "set -g @plugin \"$TMUX_RESURRECT\"" "$TMUX_CONF" 2>/dev/null; then
        {
            printf "\n# Tmux Plugin Manager and tmux-resurrect\n"
            printf "set -g @plugin 'tmux-plugins/tpm'\n"
            printf "set -g @plugin 'tmux-plugins/tmux-sensible'\n"
            printf "set -g @plugin '%s'\n\n" "$TMUX_RESURRECT"
            printf "# Initialize TPM (Tmux Plugin Manager)\n"
            printf "run '~/.tmux/plugins/tpm/tpm'\n"
        } >>"$TMUX_CONF"
        printf "Added tmux-resurrect to .tmux.conf.\n"
    else
        printf "tmux-resurrect already configured in .tmux.conf.\n"
    fi

    printf "Reloading tmux environment to install plugins...\n"
    tmux source "$TMUX_CONF" || printf "tmux is not running. Plugins will be installed on the next tmux start.\n"
}

# Function to configure fish to auto-attach to a tmux session
configure_fish() {
    printf "Configuring fish shell to use tmux...\n"
    mkdir -p "$(dirname "$FISH_CONFIG")"

    # Add tmux auto-attach logic if not already present
    if ! grep -q "tmux attach-session -t $TMUX_SESSION" "$FISH_CONFIG" 2>/dev/null; then
        {
            printf "\n\n# Automatically attach to or create a tmux session\n"
            printf "if type -q tmux # check whether tmux is installed on our system\n"
            printf "    # Check if we're already inside a tmux session\n"
            printf "    if not set -q TMUX\n"
            printf "        if tmux has-session -t %s 2>/dev/null\n" "$TMUX_SESSION"
            printf "            tmux attach-session -t %s\n" "$TMUX_SESSION"
            printf "        else\n"
            printf "            tmux new-session -s %s\n" "$TMUX_SESSION"
            printf "        end\n"
            printf "    end\n"
            printf "end\n"
        } >>"$FISH_CONFIG"
        printf "Fish configuration updated.\n"
    else
        printf "Fish configuration already set up for tmux.\n"
    fi
}

install_starship() {
    printf "Installing Starship prompt...\n"
    if ! command -v starship >/dev/null 2>&1; then
        curl -fsSL https://starship.rs/install.sh | bash -s -- -y || {
            printf "Failed to install Starship.\n" >&2
            return 1
        }
    fi

    if ! grep -q 'starship init fish' "$FISH_CONFIG" 2>/dev/null; then
        printf "\nstarship init fish | source\n" >> "$FISH_CONFIG"
    fi

    if ! grep -q 'starship init bash' "$BASHRC" 2>/dev/null; then
        {
            printf "\n# Initialize Starship for Bash\n"
            printf 'eval "$(starship init bash)"\n'
        } >> "$BASHRC"
    fi

    mkdir -p "$STARSHIP_CONFIG_DIR"

    if ! starship preset "$STARSHIP_PRESET" -o "$STARSHIP_CONFIG_FILE"; then
        printf "Failed to apply preset '%s'. Falling back to gruvbox-rainbow.\n" "$STARSHIP_PRESET" >&2
        if ! starship preset gruvbox-rainbow -o "$STARSHIP_CONFIG_FILE"; then
            printf "Failed to apply default preset. Please configure Starship manually.\n" >&2
            return 1
        fi
    fi

    printf "Starship installed with preset: %s\n" "$STARSHIP_PRESET"
}

# Function to update .bashrc to launch fish
update_bashrc() {
    printf "Updating .bashrc to launch fish...\n"
    if ! grep -q "exec fish" "$BASHRC" 2>/dev/null; then
        {
            printf "\n# Launch fish shell automatically unless bash was started from fish\n"
            printf "if command -v fish &> /dev/null && [[ \$- == *i* ]]; then\n"
            printf "    # Check if the parent process is not fish\n"
            printf "    parent_process=\$(ps -o comm= -p \$(ps -o ppid= -p \$$))\n"
            printf "    if [[ \"\$parent_process\" != \"fish\" ]]; then\n"
            printf "        exec fish\n"
            printf "    fi\n"
            printf "fi\n"
        } >>"$BASHRC"
        printf ".bashrc updated to launch fish.\n"
    else
        printf ".bashrc already configured to launch fish.\n"
    fi
}

main() {
    parse_args "$@"
    install_dependencies
    install_tmux_resurrect
    configure_fish
    install_starship
    update_bashrc

    # Prompt if no flag is provided
    if [[ -z "$INSTALL_DOCKER" ]]; then
        read -p "Do you want to install Docker? (y/n): " install_docker_choice
        if [[ "$install_docker_choice" =~ ^[Yy]$ ]]; then
            INSTALL_DOCKER=true
        else
            INSTALL_DOCKER=false
        fi
    fi

    # Install Docker if requested
    if [[ "$INSTALL_DOCKER" == true ]]; then
        install_docker
    else
        printf "Skipping Docker installation.\n"
    fi

    printf "Installation and configuration complete. Restart your terminal to start using fish, tmux, and Starship.\n"
}

main "$@"
