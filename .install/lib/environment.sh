#!/bin/bash
# lib/environment.sh - Environment detection and user management

# ============================================================================
# User Management
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

  if getent passwd "$actual_user" >/dev/null; then
    getent passwd "$actual_user" | cut -d: -f6
  else
    [[ "$actual_user" == "root" ]] && echo "/root" || echo "/home/$actual_user"
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
      su - "$actual_user" -c "$(printf ' %q' "$@")"
    fi
  fi
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
# Environment Detection
# ============================================================================

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

  # Check if running in Docker container (set -e safe)
  if [[ -f /.dockerenv ]]; then
    is_docker=true
  elif [[ -f /proc/1/cgroup ]] && grep -qE 'docker|lxc' /proc/1/cgroup 2>/dev/null; then
    is_docker=true
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
