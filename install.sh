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
readonly CONFIG_FILE="${SCRIPT_DIR}/setup.conf"

# Default configuration
declare -A CONFIG=(
    [SYSTEM_WIDE]=false
    [KEEP_GIT]=true
    [TMUX_SESSION]="default"
    [STARSHIP_PRESET]="gruvbox-rainbow"
    [ASTRONVIM_REPO]="https://github.com/jabez007/AstroNvim-config.git"
    [LOG_LEVEL]="INFO"
)

# Component definitions
declare -A COMPONENTS=(
    [base]="install_base_dependencies"
    [go]="install_go"
    [node]="install_node_stack"
    [editor]="install_editor_stack"
    [config]="install_user_configs"
    [shell]="install_shell_stack"
    [docker]="install_docker_stack"
)

# ============================================================================
# Environment Detection
# ============================================================================

# Get the actual user (not root when using sudo)
get_actual_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    elif [[ -n "${USER:-}" ]]; then
        echo "$USER"
    else
        # Fallback to whoami or id commands
        if command -v whoami >/dev/null 2>&1; then
            whoami
        else
            id -un
        fi
    fi
}

# Get user's home directory
get_user_home() {
    local actual_user
    actual_user=$(get_actual_user)

    if [[ "$actual_user" == "root" ]]; then
        echo "/root"
    else
        echo "/home/$actual_user"
    fi
}

# Execute command as actual user (not root)
run_as_user() {
    local actual_user user_home
    actual_user=$(get_actual_user)
    user_home=$(get_user_home)

    if [[ "$actual_user" == "root" ]] || [[ -z "${SUDO_USER:-}" ]]; then
        # Already running as the target user
        "$@"
    else
        # Run as the original user
        if command -v sudo >/dev/null 2>&1; then
            sudo -u "$actual_user" HOME="$user_home" "$@"
        else
            su - "$actual_user" -c "$(printf '%q ' "$@")"
        fi
    fi
}

# Detect if running in Docker or as root
detect_environment() {
    local is_docker=false
    local is_root=false
    local use_sudo=true

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        is_root=true
        use_sudo=false
    fi

    # Check if running in Docker container
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        is_docker=true
        #use_sudo=false
    fi

    # Check if `sudo` is available
    if ! command -v sudo >/dev/null 2>&1; then
        use_sudo=false
    fi

    # Export environment variables for use in other functions
    export IS_DOCKER="$is_docker"
    export IS_ROOT="$is_root"
    export USE_SUDO="$use_sudo"

    debug "Environment: Docker=$is_docker, Root=$is_root, Use sudo=$use_sudo"
    debug "Actual user: $(get_actual_user), User home: $(get_user_home)"
}

# Execute command with or without `sudo` based on environment
run_as_admin() {
    if [[ "$USE_SUDO" == "true" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
    ERROR) echo -e "\033[31m[ERROR]\033[0m $message" >&2 ;;
    WARN) echo -e "\033[33m[WARN]\033[0m $message" ;;
    INFO) echo -e "\033[32m[INFO]\033[0m $message" ;;
    DEBUG) echo -e "\033[36m[DEBUG]\033[0m $message" ;;
    esac

    # Also log to file
    echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
}

error() { log ERROR "$@"; }
warn() { log WARN "$@"; }
info() { log INFO "$@"; }
debug() { log DEBUG "$@"; }

# Exit with error
die() {
    error "$@"
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Trim whitespace
trim() {
    echo "$1" | awk '{$1=$1};1'
}

# Detect OS and architecture
detect_system() {
    local os arch

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os="$ID"
    elif command_exists lsb_release; then
        os=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [[ -f /etc/redhat-release ]]; then
        os="rhel"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os="macos"
    else
        os="unknown"
    fi

    arch=$(uname -m)
    case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    armv7l) arch="armv7" ;;
    esac

    echo "$os:$arch"
}

# Get package manager
get_package_manager() {
    if command_exists apt; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists brew; then
        echo "brew"
    elif command_exists pacman; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Install packages based on package manager
install_packages() {
    local pm packages=("$@")
    pm=$(get_package_manager)

    info "Installing packages: ${packages[*]} using $pm"

    case "$pm" in
    apt)
        run_as_admin apt update && run_as_admin apt install -y --no-install-recommends "${packages[@]}"
        ;;
    dnf)
        run_as_admin dnf clean all
        run_as_admin dnf makecache
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then
                debug "Installing $pkg..."
                run_as_admin dnf install -y "$pkg"
            else
                warn "$pkg is already installed"
                run_as_admin dnf reinstall -y "$pkg"
            fi
        done
        ;;
    yum)
        run_as_admin yum install -y "${packages[@]}"
        ;;
    brew)
        brew install "${packages[@]}"
        ;;
    pacman)
        run_as_admin pacman -S --noconfirm "${packages[@]}"
        ;;
    *)
        die "Unsupported package manager: $pm"
        ;;
    esac
}

# Update PATH and persist it
update_path() {
    local path_entry="$1"
    local comment="${2:-Add to PATH}"
    local shell_configs=()
    local run_command

    # Update current session
    export PATH="$PATH:$path_entry"

    # Determine config file
    if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
        # System-wide: Update both profile and bashrc for maximum compatibility
        shell_configs=("/etc/profile" "/etc/bash.bashrc")

        # Add zsh system config if zsh is installed
        if command_exists zsh && [[ -f "/etc/zsh/zshrc" ]]; then
            shell_configs+=("/etc/zsh/zshrc")
        fi

        run_command="run_as_admin"
    else
        # User-specific: Prefer .profile for PATH (shell-agnostic), but also update shell-specific configs
        local user_home
        user_home=$(get_user_home)

        # Start with .profile (shell-agnostic)
        shell_configs=("${user_home}/.profile")

        # Add shell-specific configs for interactive shells
        if [[ -n "${ZSH_VERSION-}" ]] || command_exists zsh; then
            shell_configs+=("${user_home}/.zshrc")
        fi

        # Add .bashrc for interactive bash sessions
        shell_configs+=("${user_home}/.bashrc")

        run_command="run_as_user"
    fi

    # Update each config file
    for shell_config in "${shell_configs[@]}"; do
        # Create directory if it doesn't exist (for user configs)
        if [[ "${CONFIG[SYSTEM_WIDE]}" != "true" ]]; then
            $run_command mkdir -p "$(dirname "$shell_config")"
        fi

        # Add to config if not present
        if ! grep -qxF "export PATH=\"\$PATH:${path_entry}\"" "$shell_config" 2>/dev/null; then
            {
                echo ""
                echo "# $comment"
                echo "export PATH=\"\$PATH:${path_entry}\""
            } | $run_command tee -a "$shell_config" >/dev/null
            info "Updated PATH in $shell_config"
        fi
    done
}

# Verify installation
verify_installation() {
    local command="$1"
    local name="${2:-$command}"

    if command_exists "$command"; then
        info "$name installed successfully"
        return 0
    else
        error "$name installation failed - command not found"
        return 1
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

install_base_dependencies() {
    info "Installing base dependencies..."

    local packages=(
        bash curl git
        unzip ca-certificates
        ripgrep
    )

    # Add python and lua based on OS
    local pm
    pm=$(get_package_manager)
    case "$pm" in
    apt)
        packages+=(
            build-essential libssl-dev
            libffi-dev openssh-client
            lua5.1 python3 python3-venv
        )
        ;;
    dnf | yum)
        packages+=(
            gcc gcc-c++ make openssl-devel
            libffi-devel openssh-clients
            lua python3 python3-virtualenv
        )
        ;;
    brew)
        # already satisfied by Xcode Command Line Tools / pkg-config
        packages+=(lua python)
        ;;
    pacman)
        packages+=(
            base-devel openssh
            lua python python-virtualenv
        )
        ;;
    esac

    install_packages "${packages[@]}"
}

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

install_user_configs() {
    info "Installing user configurations..."

    # Ensure git is present before using or configuring it
    if ! command_exists git; then
        warn "Git not found – installing base dependencies"
        install_base_dependencies        # guarantees git
    fi

    # Install AstroNvim config
    install_astronvim_config

    # Configure git with best practices
    setup_git_config

    info "User configurations installed successfully"
}

install_astronvim_config() {
    info "Installing AstroNvim configuration..."

    local user_home
    user_home=$(get_user_home)

    local config_dir="${user_home}/.config/nvim"

    if [[ -d "$config_dir" ]]; then
        warn "Neovim config directory exists, skipping AstroNvim setup"
        return 0
    fi

    git clone --depth 1 "${CONFIG[ASTRONVIM_REPO]}" "$config_dir" ||
        die "Failed to clone AstroNvim config"

    if [[ "${CONFIG[KEEP_GIT]}" != "true" ]]; then
        rm -rf "${config_dir}/.git"
    fi

    info "AstroNvim configuration installed"
}

setup_git_config() {
    info "Setting up git configuration with best practices..."

    # Always operate as the actual (non-root) user
    local git_cfg=(git config --global)
    if [[ "$IS_ROOT" == "true" ]]; then
        git_cfg=(run_as_user git config --global)
    fi

    # Core settings
    "${git_cfg[@]}" init.defaultBranch main
    "${git_cfg[@]}" core.autocrlf input
    "${git_cfg[@]}" core.safecrlf true
    "${git_cfg[@]}" pull.rebase true
    "${git_cfg[@]}" push.default simple
    "${git_cfg[@]}" fetch.prune true
    "${git_cfg[@]}" rebase.autoStash true

    # Better diff and merge tools
    "${git_cfg[@]}" diff.algorithm patience
    "${git_cfg[@]}" merge.conflictstyle diff3
    "${git_cfg[@]}" rerere.enabled true

    # Security and performance
    "${git_cfg[@]}" transfer.fsckobjects true
    "${git_cfg[@]}" fetch.fsckobjects true
    "${git_cfg[@]}" receive.fsckObjects true
    "${git_cfg[@]}" gc.auto 1

    # Better output formatting
    "${git_cfg[@]}" color.ui auto
    "${git_cfg[@]}" branch.sort -committerdate
    "${git_cfg[@]}" tag.sort version:refname

    # Useful aliases
    "${git_cfg[@]}" alias.st status
    "${git_cfg[@]}" alias.co checkout
    "${git_cfg[@]}" alias.br branch
    "${git_cfg[@]}" alias.ci commit
    "${git_cfg[@]}" alias.unstage 'reset HEAD --'
    "${git_cfg[@]}" alias.last 'log -1 HEAD'
    "${git_cfg[@]}" alias.visual '!gitk'
    "${git_cfg[@]}" alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

    # Only set user info if not already configured
    if ! "${git_cfg[@]}" user.name &>/dev/null; then
        if [[ -n "${CONFIG[GIT_USER_NAME]:-}" ]]; then
            "${git_cfg[@]}" user.name "${CONFIG[GIT_USER_NAME]}"
            info "Git user.name set to: ${CONFIG[GIT_USER_NAME]}"
        else
            warn "Git user.name not configured - set CONFIG[GIT_USER_NAME] or run 'git config --global user.name \"Your Name\"'"
        fi
    fi

    if ! "${git_cfg[@]}" user.email &>/dev/null; then
        if [[ -n "${CONFIG[GIT_USER_EMAIL]:-}" ]]; then
            "${git_cfg[@]}" user.email "${CONFIG[GIT_USER_EMAIL]}"
            info "Git user.email set to: ${CONFIG[GIT_USER_EMAIL]}"
        else
            warn "Git user.email not configured - set CONFIG[GIT_USER_EMAIL] or run 'git config --global user.email \"you@example.com\"'"
        fi
    fi

    info "Git configuration setup completed"
}

install_shell_stack() {
    info "Installing shell stack (Fish, Tmux, Starship)..."

    # Install Fish and Tmux
    install_packages fish tmux

    # Install Starship
    if ! command_exists starship; then
        info "Installing Starship..."
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y ||
            die "Failed to install Starship"
    else
        info "Starship already installed"
    fi

    # Configure shells
    configure_fish_shell
    configure_fish_nvm
    configure_tmux
    configure_starship
    configure_bash_integration
}

configure_fish_shell() {
    info "Configuring Fish shell..."

    local user_home
    user_home=$(get_user_home)

    local fish_config="${user_home}/.config/fish/config.fish"
    run_as_user mkdir -p "$(dirname "$fish_config")"

    # Add tmux auto-attach if not present
    if ! grep -q "tmux attach-session -t ${CONFIG[TMUX_SESSION]}" "$fish_config" 2>/dev/null; then
        run_as_user tee -a "$fish_config" >/dev/null <<EOF

# Automatically attach to or create a tmux session
if type -q tmux
    if not set -q TMUX
        if tmux has-session -t ${CONFIG[TMUX_SESSION]} 2>/dev/null
            tmux attach-session -t ${CONFIG[TMUX_SESSION]}
        else
            tmux new-session -s ${CONFIG[TMUX_SESSION]}
        end
    end
end
EOF
        info "Fish configured for tmux auto-attach"
    fi
}

configure_tmux() {
    info "Configuring Tmux..."

    local user_home
    user_home=$(get_user_home)

    local tmux_conf="${user_home}/.tmux.conf"
    local tpm_dir="${user_home}/.tmux/plugins/tpm"

    # Install TPM if not present
    if [[ ! -d "$tpm_dir" ]]; then
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir" ||
            warn "Failed to install TPM"
    fi

    # Configure tmux.conf if not already configured
    if ! grep -q "tmux-plugins/tmux-resurrect" "$tmux_conf" 2>/dev/null; then
        run_as_user tee -a "$tmux_conf" >/dev/null <<'EOF'

# Tmux Plugin Manager and plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'

# Initialize TPM (keep this line at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
EOF
        info "Tmux configuration updated"
    fi
}

configure_starship() {
    info "Configuring Starship prompt..."

    local user_home
    user_home=$(get_user_home)

    local starship_config="${user_home}/.config/starship.toml"
    run_as_user mkdir -p "$(dirname "$starship_config")"

    # Apply preset
    run_as_user starship preset "${CONFIG[STARSHIP_PRESET]}" -o "$starship_config" ||
        warn "Failed to apply Starship preset: ${CONFIG[STARSHIP_PRESET]}"

    # Add to Fish config
    local fish_config="${user_home}/.config/fish/config.fish"
    if ! grep -q 'starship init fish' "$fish_config" 2>/dev/null; then
        run_as_user bash -c 'echo "starship init fish | source" >>"'"$fish_config"'"'
    fi

    # Add to bashrc
    local bashrc="${user_home}/.bashrc"
    if ! grep -q 'starship init bash' "$bashrc" 2>/dev/null; then
        run_as_user tee -a "$bashrc" >/dev/null <<'EOF'

# Initialize Starship for Bash
eval "$(starship init bash)"
EOF
    fi
}

configure_bash_integration() {
    info "Configuring Bash to Fish integration..."

    local user_home
    user_home=$(get_user_home)

    local bashrc="${user_home}/.bashrc"

    if ! grep -q "exec fish" "$bashrc" 2>/dev/null; then
        run_as_user tee -a "$bashrc" >/dev/null <<'EOF'

# Launch fish shell automatically unless bash was started from fish
if command -v fish &> /dev/null && [[ $- == *i* ]]; then
    parent_process=$(ps -o comm= -p $(ps -o ppid= -p $$))
    if [[ "$parent_process" != "fish" ]]; then
        exec fish
    fi
fi
EOF
        info "Bash configured to launch Fish automatically"
    fi
}

install_docker_stack() {
    info "Installing Docker..."

    if command_exists docker; then
        info "Docker already installed"
        return 0
    fi

    local pm os
    pm=$(get_package_manager)
    os=$(detect_system | cut -d: -f1)

    case "$pm" in
    apt)
        # Ubuntu/Debian Docker installation
        run_as_admin apt update
        run_as_admin apt install -y ca-certificates curl gnupg
        run_as_admin install -m 0755 -d /etc/apt/keyrings

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
            run_as_admin gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        run_as_admin chmod a+r /etc/apt/keyrings/docker.gpg

        source /etc/os-release
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${VERSION_CODENAME:-stable} stable" |
            run_as_admin tee /etc/apt/sources.list.d/docker.list >/dev/null

        run_as_admin apt update
        run_as_admin apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
    dnf)
        # Fedora Docker installation
        run_as_admin dnf -y install dnf-plugins-core
        run_as_admin dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        run_as_admin dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        run_as_admin systemctl start docker
        run_as_admin systemctl enable docker
        ;;
    brew)
        # macOS Docker installation
        brew install --cask docker
        ;;
    *)
        warn "Docker installation not supported for package manager: $pm"
        return 1
        ;;
    esac

    # Post-installation setup
    if [[ "$os" != "macos" ]]; then
        run_as_admin groupadd docker 2>/dev/null || true
        run_as_admin usermod -aG docker "$(get_actual_user)"
        info "Added user to docker group. You may need to log out and back in."
    fi

    verify_installation docker "Docker"
}

# ============================================================================
# Configuration Management
# ============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        debug "Loading configuration from $CONFIG_FILE"
        # shellcheck source=./astro-nvim/setup.conf
        source "$CONFIG_FILE"

        # sync scalar vars -> associative array
        for k in SYSTEM_WIDE KEEP_GIT TMUX_SESSION \
            STARSHIP_PRESET ASTRONVIM_REPO LOG_LEVEL; do
            [[ -v $k ]] && CONFIG[$k]="${!k}"
        done
    fi
}

save_config() {
    info "Saving configuration to $CONFIG_FILE"
    cat >"$CONFIG_FILE" <<EOF
# Development Environment Setup Configuration
# Generated on $(date)

SYSTEM_WIDE=${CONFIG[SYSTEM_WIDE]}
KEEP_GIT=${CONFIG[KEEP_GIT]}
TMUX_SESSION="${CONFIG[TMUX_SESSION]}"
STARSHIP_PRESET="${CONFIG[STARSHIP_PRESET]}"
ASTRONVIM_REPO="${CONFIG[ASTRONVIM_REPO]}"
LOG_LEVEL="${CONFIG[LOG_LEVEL]}"
EOF
}

# ============================================================================
# Command Line Interface
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMPONENTS...]

A modular Linux development environment setup script.

COMPONENTS:
    base     - Base dependencies (curl, git, build tools, etc.)
    go       - Go programming language
    node     - Node.js stack (NVM, Node.js, Deno)
    editor   - Editor stack (Neovim, LazyGit, Bottom, AstroNvim)
    config   - User configurations (AstroNvim, dotfiles)
    shell    - Shell stack (Fish, Tmux, Starship)
    docker   - Docker and Docker Compose
    all      - Install all components

OPTIONS:
    --debug, -d              Enable debug output
    --system-wide, -s        Install system-wide where applicable
    --keep-git               Keep .git directories in cloned configs
    --tmux-session NAME      Tmux session name (default: ${CONFIG[TMUX_SESSION]})
    --starship-preset NAME   Starship preset (default: ${CONFIG[STARSHIP_PRESET]})
    --astronvim-repo URL     AstroNvim config repository
    --save-config            Save current configuration
    --help, -h               Show this help message

EXAMPLES:
    $0 base go editor        # Install base tools, Go, and editor stack
    $0 --debug all           # Install everything with debug output
    $0 --system-wide base    # Install base dependencies system-wide
    $0 editor config         # Install editor tools and user configs separately
    $0 --save-config         # Save current configuration

LOGS:
    Setup logs are written to: $LOG_FILE

NOTES:
    - 'editor' installs system-wide tools (Neovim, LazyGit, Bottom)
    - 'config' installs user-specific configurations (AstroNvim config)
    - When running as root or with sudo, configs are installed to the original user's home
EOF
}

parse_arguments() {
    local components=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --debug | -d)
            CONFIG[LOG_LEVEL]=DEBUG
            shift
            ;;
        --system-wide | -s)
            CONFIG[SYSTEM_WIDE]=true
            shift
            ;;
        --keep-git)
            CONFIG[KEEP_GIT]=true
            shift
            ;;
        --tmux-session)
            [[ $# -ge 2 ]] || die "--tmux-session requires a session name argument"
            CONFIG[TMUX_SESSION]="$2"
            shift 2
            ;;
        --starship-preset)
            [[ $# -ge 2 ]] || die "--starship-preset requires a preset name argument"
            CONFIG[STARSHIP_PRESET]="$2"
            shift 2
            ;;
        --astronvim-repo)
            [[ $# -ge 2 ]] || die "--astronvim-repo requires a git URL argument"
            CONFIG[ASTRONVIM_REPO]="$2"
            shift 2
            ;;
            #        --config)
            #            [[ $# -ge 2 ]] || die "--config requires a filepath argument"
            #            CONFIG_FILE="$2"
            #            shift 2
            #            ;;
        --save-config)
            save_config
            exit 0
            ;;
        --help | -h)
            show_usage
            exit 0
            ;;
        base | go | node | editor | config | shell | docker)
            components+=("$1")
            shift
            ;;
        all)
            components=(base go node editor config shell docker)
            shift
            ;;
        *)
            die "Unknown option: $1\nUse --help for usage information."
            ;;
        esac
    done

    # If no components specified, show usage
    if [[ ${#components[@]} -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # Return the components list
    echo "${components[@]}"
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
