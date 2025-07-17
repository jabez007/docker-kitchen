#!/bin/bash
# install.sh - Modular Linux Development Environment Setup
# Usage: ./install.sh [OPTIONS] [COMPONENTS...]
# Components: base, go, node, editor, shell, docker
# Example: ./install.sh --debug base go editor

set -euo pipefail

# ============================================================================
# Configuration and Constants
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/setup.log"
readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/jabez007/docker-kitchen/refs/heads/master"

# ============================================================================
# Module Loading Functions
# ============================================================================

download_missing_module() {
    local module_path="$1"
    local relative_path="${module_path#"$SCRIPT_DIR"/}" # Strips off the $SCRIPT_DIR/ prefix from the absolute path to get the relative path within the repo
    local download_url="${GITHUB_BASE_URL}/${relative_path}"
    
    echo "Downloading missing module: $relative_path"
    mkdir -p "$(dirname "$module_path")"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$download_url" -o "$module_path" || {
            echo "Error: Failed to download $relative_path from $download_url" >&2
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O "$module_path" || {
            echo "Error: Failed to download $relative_path from $download_url" >&2
            return 1
        }
    else
        echo "Error: Neither curl nor wget is available to download missing modules" >&2
        return 1
    fi
}

safe_source() {
    local module_path="$1"
    
    if [[ ! -f "$module_path" ]]; then
        download_missing_module "$module_path" || exit 1
    fi
    
    source "$module_path"
}

# Load helper modules
safe_source "${SCRIPT_DIR}/.install/lib/config.sh"
safe_source "${SCRIPT_DIR}/.install/lib/utils.sh"
safe_source "${SCRIPT_DIR}/.install/lib/environment.sh"
safe_source "${SCRIPT_DIR}/.install/lib/package_manager.sh"
safe_source "${SCRIPT_DIR}/.install/lib/cli.sh"

# Load installation modules
safe_source "${SCRIPT_DIR}/.install/modules/base.sh"
#safe_source "${SCRIPT_DIR}/.install/modules/go.sh"
#safe_source "${SCRIPT_DIR}/.install/modules/node.sh"
#safe_source "${SCRIPT_DIR}/.install/modules/editor.sh"
safe_source "${SCRIPT_DIR}/.install/modules/config.sh"
safe_source "${SCRIPT_DIR}/.install/modules/shell.sh"
safe_source "${SCRIPT_DIR}/.install/modules/docker.sh"

# ============================================================================
# Installation Functions
# ============================================================================

install_go() {
    if command_exists go; then
        info "Go is already installed, skipping..."
        return 0
    fi

    info "Installing Go..."
    local go_ver go_url arch

    arch=$(uname -m)
    case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    armv6l) arch="armv6l" ;;
    armv7l) arch="armv6l" ;;
    i386) arch="386" ;;
    esac

    go_ver=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n1) ||
        die "Unable to resolve latest Go version"
    [[ -n "$go_ver" ]] || die "Unable to resolve latest Go version"
    go_url="https://go.dev/dl/${go_ver}.linux-${arch}.tar.gz"

    debug "Go download URL: $go_url"

    curl -L "$go_url" -o /tmp/go.tar.gz || die "Failed to download Go"
    run_as_admin rm -rf /usr/local/go
    run_as_admin tar -C /usr/local -xzf /tmp/go.tar.gz || die "Failed to extract Go"
    rm /tmp/go.tar.gz

    update_path "/usr/local/go/bin" "Go binaries"
    verify_installation go "Go"
}

install_node_stack() {
    info "Installing Node.js stack (NVM, Node, Deno)..."

    local user_home
    user_home=$(get_user_home)

    # Install NVM
    if [[ ! -s "$user_home/.nvm/nvm.sh" ]]; then
        info "Installing NVM..."
        local nvm_version
        nvm_version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest |
            grep '"tag_name"' | cut -d '"' -f 4)

        run_as_user bash -c \
            "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh | bash" ||
            die "NVM installation failed"

        export NVM_DIR="${user_home}/.nvm"
        # shellcheck disable=SC1091
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
        # shellcheck disable=SC1091
        [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    else
        info "NVM already installed"
        export NVM_DIR="${user_home}/.nvm"
        # shellcheck disable=SC1091
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
        # shellcheck disable=SC1091
        [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    fi

    # Install latest LTS Node.js
    if ! command_exists node; then
        info "Installing Node.js LTS..."
        run_as_user bash -c \
            "source $user_home/.nvm/nvm.sh && nvm install --lts" ||
            die "Node.js installation failed"
        #nvm use --lts
    fi

    # Install Deno
    if ! command_exists unzip; then
        install_packages unzip
    fi
    if ! command_exists deno; then
        info "Installing Deno..."
        run_as_user bash -c \
            "curl -fsSL https://deno.land/install.sh | sh -s -- -y" ||
            die "Deno installation failed"
        update_path "$user_home/.deno/bin" "Deno binaries"
    else
        info "Deno already installed"
    fi

    # Configure Fish for NVM if Fish is available
    if command_exists fish; then
        configure_fish_nvm
    fi
}

configure_fish_nvm() {
    info "Configuring Fish shell for NVM..."

    local user_home
    user_home=$(get_user_home)

    # Install Fisher if not present
    local fisher_path="$user_home/.config/fish/functions/fisher.fish"
    if [[ ! -f "$fisher_path" ]]; then
        run_as_user bash -c \
            "curl -sL https://git.io/fisher --create-dirs -o \"$fisher_path\"" ||
            die "Fisher installation failed – aborting Fish/NVM configuration"
    fi

    # Install Bass plugin for NVM
    if command_exists fish && [[ -f "$fisher_path" ]]; then
        run_as_user fish -c 'fisher install edc/bass' 2>/dev/null ||
            warn "Failed to install Bass plugin"

        # Create NVM function for Fish
        local nvm_fish_file="$user_home/.config/fish/functions/nvm.fish"
        if [[ ! -f "$nvm_fish_file" ]]; then
            run_as_user mkdir -p "$(dirname "$nvm_fish_file")"
            run_as_user tee "$nvm_fish_file" >/dev/null <<'EOF'
function nvm
    bass source ~/.nvm/nvm.sh --no-use ';' nvm $argv
end
EOF
            info "NVM configured for Fish shell"
        fi
    fi
}

install_editor_stack() {
    info "Installing editor stack (Neovim, LazyGit, Bottom)..."

    # Install Neovim
    if ! command_exists nvim; then
        info "Installing Neovim..."
        local arch nvim_tarball

        arch=$(uname -m)
        case "$arch" in
        x86_64) nvim_tarball="nvim-linux-x86_64" ;;
        aarch64 | arm64) nvim_tarball="nvim-linux-arm64" ;;
        *) die "Unsupported architecture for Neovim: $arch" ;;
        esac

        curl -LO "https://github.com/neovim/neovim/releases/download/stable/${nvim_tarball}.tar.gz" ||
            die "Failed to download Neovim"

        run_as_admin rm -rf /opt/nvim*
        run_as_admin tar -C /opt -xzf "${nvim_tarball}.tar.gz" || die "Failed to extract Neovim"
        run_as_admin ln -sf "/opt/${nvim_tarball}/bin/nvim" /usr/local/bin/nvim
        rm "${nvim_tarball}.tar.gz"

        verify_installation nvim "Neovim"
    else
        info "Neovim already installed"
    fi

    # Install LazyGit
    if ! command_exists lazygit; then
        info "Installing LazyGit..."
        local lazygit_arch lazygit_url

        # Map uname -m output to LazyGit architecture naming
        case "$(uname -m)" in
        x86_64) lazygit_arch="x86_64" ;;
        aarch64 | arm64) lazygit_arch="arm64" ;;
        armv7l | armv6l | arm*) lazygit_arch="armv6" ;;
        *) die "Unsupported architecture for LazyGit: $(uname -m)" ;;
        esac

        debug "LazyGit architecture: $lazygit_arch"

        lazygit_url=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
            grep "browser_download_url.*lazygit.*$(uname -s).*${lazygit_arch}.*tar.gz" |
            cut -d : -f 2,3 | tr -d \" | tail -n 1)
        lazygit_url=$(trim "$lazygit_url")

        debug "LazyGit download URL: $lazygit_url"

        [[ -n "$lazygit_url" ]] || die "Could not resolve LazyGit download URL"

        curl -L "$lazygit_url" -o /tmp/lazygit.tar.gz || die "Failed to download LazyGit"
        run_as_admin tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
        rm /tmp/lazygit.tar.gz

        verify_installation lazygit "LazyGit"
    else
        info "LazyGit already installed"
    fi

    # Install Bottom
    if ! command_exists btm; then
        info "Installing Bottom..."
        local pm
        pm=$(get_package_manager)

        if [[ "$pm" == "apt" ]]; then
            local bottom_url
            bottom_url=$(curl -s https://api.github.com/repos/ClementTsang/bottom/releases/latest |
                grep "browser_download_url.*bottom.*$(dpkg --print-architecture).*deb" |
                cut -d : -f 2,3 | tr -d \" | tail -n 1)
            bottom_url=$(trim "$bottom_url")

            debug "Bottom download URL: $bottom_url"

            if [[ -n "$bottom_url" ]]; then
                curl -L "$bottom_url" -o /tmp/bottom.deb
                run_as_admin apt install -y /tmp/bottom.deb
                rm /tmp/bottom.deb
            else
                warn "Could not install Bottom via deb package"
            fi
        elif [[ "$pm" == "dnf" ]]; then
            local bottom_url
            bottom_url=$(curl -s https://api.github.com/repos/ClementTsang/bottom/releases/latest |
                grep "browser_download_url.*bottom.*$(rpm --eval %{_arch}).*rpm" |
                grep -v "musl" |
                cut -d : -f 2,3 | tr -d \" | tail -n 1)
            bottom_url=$(trim "$bottom_url")

            debug "Bottom download URL: $bottom_url"

            if [[ -n "$bottom_url" ]]; then
                curl -L "$bottom_url" -o /tmp/bottom.rpm
                run_as_admin dnf install -y /tmp/bottom.rpm
                rm /tmp/bottom.rpm
            else
                warn "Could not install Bottom via rpm package"
            fi
        else
            # Try package manager
            case "$pm" in
            brew) brew install bottom ;;
            pacman) run_as_admin pacman -S --noconfirm bottom ;;
            *) warn "Bottom not available via $pm, skipping..." ;;
            esac
        fi

        verify_installation btm "Bottom"
    else
        info "Bottom already installed"
    fi

    info "Editor stack installation complete. Use 'config' component to install AstroNvim configuration."
    # install_astronvim_config
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local components

    # Load configuration
    load_config

    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    info "Starting development environment setup"
    detect_environment
    info "System: $(detect_system), Package Manager: $(get_package_manager)"

    # Run directly in main shell to allow proper exiting
    local parsed
    parsed="$(parse_arguments "$@")" || exit $?

    # Convert output into an array
    IFS=' ' read -r -a components <<<"$parsed"

    info "Components to install: ${components[*]}"

    # Process each component
    for component in "${components[@]}"; do
        if [[ -n "${COMPONENTS[$component]:-}" ]]; then
            info "Installing component: $component"
            ${COMPONENTS[$component]} || die "Failed to install component: $component"
        else
            warn "Unknown component: $component"
        fi
    done

    info "Setup completed successfully!"
    info "Log file: $LOG_FILE"

    # Show next steps
    cat <<EOF

=== Next Steps ===
1. Restart your terminal or run: source ~/.bashrc
2. If Docker was installed, you may need to log out and back in
3. For tmux plugins, run: tmux source ~/.tmux.conf and press prefix + I
4. Check the log file for any warnings: $LOG_FILE

EOF
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
