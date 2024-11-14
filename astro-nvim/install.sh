#!/bin/bash

# Script to install tmux and fish, configure fish to attach or create a tmux session,
# and update .bashrc to launch fish automatically while keeping bash as the default shell.

set -euo pipefail

# Define constants
TMUX_SESSION="default"
FISH_CONFIG="$HOME/.config/fish/config.fish"
BASHRC="$HOME/.bashrc"

# Function to install dependencies
install_dependencies() {
    printf "Installing tmux and fish...\n"
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y tmux fish
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y tmux fish
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y tmux fish
    elif command -v brew >/dev/null 2>&1; then
        brew install tmux fish
    else
        printf "Unsupported package manager. Install tmux and fish manually.\n" >&2
        return 1
    fi
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
        } >> "$FISH_CONFIG"
        printf "Fish configuration updated.\n"
    else
        printf "Fish configuration already set up for tmux.\n"
    fi
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
        } >> "$BASHRC"
        printf ".bashrc updated to launch fish.\n"
    else
        printf ".bashrc already configured to launch fish.\n"
    fi
}

main() {
    install_dependencies
    configure_fish
    update_bashrc
    printf "Installation and configuration complete. Restart your terminal to start using fish with tmux.\n"
}

main "$@"
