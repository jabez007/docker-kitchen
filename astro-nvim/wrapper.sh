#!/bin/bash
# setup - Wrapper script for install.sh
# Provides easy presets and common installation scenarios

set -euo pipefail

# ============================================================================
# Constants
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SETUP_SCRIPT="${SCRIPT_DIR}/install.sh"
readonly CONFIG_FILE="${SCRIPT_DIR}/setup.conf"

# ============================================================================
# Utility Functions
# ============================================================================

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $*"
}

# Check if main script exists
check_setup_script() {
    if [[ ! -f "$SETUP_SCRIPT" ]]; then
        log_error "install.sh not found in $SCRIPT_DIR"
        exit 1
    fi

    if [[ ! -x "$SETUP_SCRIPT" ]]; then
        log_warn "Making install.sh executable"
        chmod +x "$SETUP_SCRIPT"
    fi
}

# ============================================================================
# Preset Configurations
# ============================================================================

preset_minimal() {
    log_info "Installing minimal development environment..."
    "$SETUP_SCRIPT" --config "$CONFIG_FILE" base
}

preset_basic() {
    log_info "Installing basic development environment..."
    "$SETUP_SCRIPT" --config "$CONFIG_FILE" base go editor
}

preset_web() {
    log_info "Installing web development environment..."
    "$SETUP_SCRIPT" --config "$CONFIG_FILE" base node editor shell
}

preset_full() {
    log_info "Installing full development environment..."
    "$SETUP_SCRIPT" --config "$CONFIG_FILE" base go node editor shell
}

preset_docker() {
    log_info "Installing development environment with Docker..."
    "$SETUP_SCRIPT" --config "$CONFIG_FILE" --install-docker base go node editor shell docker
}

preset_custom() {
    log_info "Installing custom development environment..."
    local components=("$@")
    "$SETUP_SCRIPT" --config "$CONFIG_FILE" "${components[@]}"
}

# ============================================================================
# Interactive Setup
# ============================================================================

interactive_setup() {
    echo -e "${BLUE}=== Interactive Development Environment Setup ===${NC}"
    echo

    # Component selection
    local components=()
    local component_descriptions=(
        "base:Base dependencies (curl, git, build tools, etc.)"
        "go:Go programming language"
        "node:Node.js stack (NVM, Node.js, Deno)"
        "editor:Editor stack (Neovim, LazyGit, Bottom, AstroNvim)"
        "shell:Shell stack (Fish, Tmux, Starship)"
        "docker:Docker and Docker Compose"
    )

    echo "Select components to install:"
    for desc in "${component_descriptions[@]}"; do
        local component="${desc%%:*}"
        local description="${desc#*:}"

        echo -n -e "${CYAN}Install ${component}${NC} (${description})? [y/N]: "
        read -r response
        if [[ $response =~ ^[Yy]$ ]]; then
            components+=("$component")
        fi
    done

    if [[ ${#components[@]} -eq 0 ]]; then
        log_warn "No components selected. Exiting."
        exit 0
    fi

    # Additional options
    local args=("--config" "$CONFIG_FILE")

    echo -n -e "${CYAN}Enable debug output?${NC} [y/N]: "
    read -r response
    if [[ $response =~ ^[Yy]$ ]]; then
        args+=("--debug")
    fi

    echo -n -e "${CYAN}Install system-wide where applicable?${NC} [y/N]: "
    read -r response
    if [[ $response =~ ^[Yy]$ ]]; then
        args+=("--system-wide")
    fi

    if [[ " ${components[*]} " =~ " docker " ]]; then
        echo -n -e "${CYAN}Install Docker without prompting?${NC} [y/N]: "
        read -r response
        if [[ $response =~ ^[Yy]$ ]]; then
            args+=("--install-docker")
        fi
    fi

    # Execute setup
    log_info "Starting installation with components: ${components[*]}"
    "$SETUP_SCRIPT" "${args[@]}" "${components[@]}"
}

# ============================================================================
# Configuration Management
# ============================================================================

show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Current configuration:"
        echo
        cat "$CONFIG_FILE"
    else
        log_warn "Configuration file not found: $CONFIG_FILE"
    fi
}

edit_config() {
    local editor="${EDITOR:-nano}"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "Creating new configuration file..."
        "$SETUP_SCRIPT" --save-config
    fi

    log_info "Opening configuration file with $editor..."
    "$editor" "$CONFIG_FILE"
}

reset_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -n -e "${YELLOW}Reset configuration to defaults?${NC} [y/N]: "
        read -r response
        if [[ $response =~ ^[Yy]$ ]]; then
            rm -f "$CONFIG_FILE"
            "$SETUP_SCRIPT" --save-config
            log_info "Configuration reset to defaults"
        fi
    else
        log_info "Creating default configuration..."
        "$SETUP_SCRIPT" --save-config
    fi
}

# ============================================================================
# System Information
# ============================================================================

show_system_info() {
    log_info "System Information:"
    echo

    # OS Information
    echo -e "${PURPLE}Operating System:${NC}"
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "  Distribution: $PRETTY_NAME"
        echo "  Version: $VERSION_ID"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  Distribution: macOS"
        echo "  Version: $(sw_vers -productVersion)"
    else
        echo "  Distribution: Unknown"
    fi

    # Architecture
    echo -e "${PURPLE}Architecture:${NC}"
    echo "  CPU: $(uname -m)"
    echo "  Kernel: $(uname -r)"

    # Package Manager
    echo -e "${PURPLE}Package Manager:${NC}"
    if command -v apt >/dev/null 2>&1; then
        echo "  Primary: apt ($(apt --version | head -n1))"
    elif command -v dnf >/dev/null 2>&1; then
        echo "  Primary: dnf ($(dnf --version | head -n1))"
    elif command -v yum >/dev/null 2>&1; then
        echo "  Primary: yum ($(yum --version | head -n1))"
    elif command -v brew >/dev/null 2>&1; then
        echo "  Primary: brew ($(brew --version | head -n1))"
    elif command -v pacman >/dev/null 2>&1; then
        echo "  Primary: pacman ($(pacman --version | head -n1))"
    else
        echo "  Primary: Unknown"
    fi

    # Available Tools
    echo -e "${PURPLE}Development Tools Status:${NC}"
    local tools=("curl" "git" "go" "node" "deno" "nvim" "fish" "tmux" "starship" "lazygit" "btm" "docker")

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version
            case "$tool" in
            node) version="$(node --version 2>/dev/null || echo "unknown")" ;;
            go) version="$(go version 2>/dev/null | awk '{print $3}' || echo "unknown")" ;;
            docker) version="$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo "unknown")" ;;
            *) version="$(command -v "$tool" 2>/dev/null || echo "unknown")" ;;
            esac
            echo -e "  ${tool}: ${GREEN}✓${NC} ${version}"
        else
            echo -e "  ${tool}: ${RED}✗${NC} not installed"
        fi
    done
}

# ============================================================================
# Usage and Help
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

A wrapper script for install.sh that provides easy presets and utilities.

COMMANDS:
    preset PRESET       Run a preset configuration
    interactive         Interactive setup wizard
    config              Configuration management
    info                Show system information
    help                Show this help message

PRESETS:
    minimal             Base dependencies only
    basic               Base + Go + Editor
    web                 Base + Node + Editor + Shell
    full                Base + Go + Node + Editor + Shell
    docker              Full preset + Docker
    custom COMPONENTS   Custom component selection

CONFIG COMMANDS:
    show                Show current configuration
    edit                Edit configuration file
    reset               Reset configuration to defaults

EXAMPLES:
    $0 preset minimal           # Install minimal environment
    $0 preset web               # Install web development environment
    $0 preset custom base go    # Install base dependencies and Go
    $0 interactive              # Run interactive setup wizard
    $0 config show              # Show current configuration
    $0 config edit              # Edit configuration file
    $0 info                     # Show system information

DIRECT COMPONENT INSTALLATION:
    You can also install components directly:
    $0 base go editor           # Install base, Go, and editor components

EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    # Check if main setup script exists
    check_setup_script

    # Handle no arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # Parse commands
    case "$1" in
    preset)
        if [[ $# -lt 2 ]]; then
            log_error "Preset command requires a preset name"
            show_usage
            exit 1
        fi

        case "$2" in
        minimal) preset_minimal ;;
        basic) preset_basic ;;
        web) preset_web ;;
        full) preset_full ;;
        docker) preset_docker ;;
        custom)
            shift 2
            preset_custom "$@"
            ;;
        *)
            log_error "Unknown preset: $2"
            show_usage
            exit 1
            ;;
        esac
        ;;
    interactive)
        interactive_setup
        ;;
    config)
        case "${2:-show}" in
        show) show_config ;;
        edit) edit_config ;;
        reset) reset_config ;;
        *)
            log_error "Unknown config command: $2"
            show_usage
            exit 1
            ;;
        esac
        ;;
    info)
        show_system_info
        ;;
    help | --help | -h)
        show_usage
        ;;
    base | go | node | editor | shell | docker)
        # Direct component installation
        log_info "Installing components directly: $*"
        "$SETUP_SCRIPT" --config "$CONFIG_FILE" "$@"
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
