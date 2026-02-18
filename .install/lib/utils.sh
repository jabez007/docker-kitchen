#!/bin/bash
# lib/utils.sh - Utility functions

# ============================================================================
# Logging Functions
# ============================================================================

# Logging functions
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  local current="${CONFIG[LOG_LEVEL]:-INFO}"
  # Basic priority map
  local -A prio=([ERROR]=0 [WARN]=1 [INFO]=2 [DEBUG]=3)
  ((${prio[$level]} > ${prio[$current]})) && return

  case "$level" in
  ERROR) echo -e "\033[31m[ERROR]\033[0m $message" >&2 ;;
  WARN) echo -e "\033[33m[WARN]\033[0m $message" ;;
  INFO) echo -e "\033[32m[INFO]\033[0m $message" ;;
  DEBUG) echo -e "\033[36m[DEBUG]\033[0m $message" ;;
  esac

  # Also log to file
  if [[ -n "${LOG_FILE:-}" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
  fi
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

# ============================================================================
# System Utilities
# ============================================================================

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

# ============================================================================
# Path Management
# ============================================================================

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

  # Fish shell specific PATH update
  if command_exists fish; then
    local escaped_path
    escaped_path=$(printf '%q' "$path_entry")
    if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
      run_as_admin fish -c "fish_add_path -m $escaped_path" 2>/dev/null || true
    else
      run_as_user fish -c "fish_add_path -m $escaped_path" 2>/dev/null || true
    fi
    info "Updated PATH for Fish shell"
  fi
}

# ============================================================================
# Installation Verification
# ============================================================================

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
