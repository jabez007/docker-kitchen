#!/bin/bash
# lib/package_manager.sh - Package manager abstraction

# Get package manager
get_package_manager() {
  if command_exists apt-get; then
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

# Install packages based on package manager. With --upgrade, packages that are
# already installed are upgraded too (apt-get install and pacman -Syu always do).
install_packages() {
  local pm packages=("$@")
  pm=$(get_package_manager)

  info "Installing packages: ${packages[*]} using $pm"

  case "$pm" in
  apt)
    run_as_admin apt-get update
    run_as_admin env DEBIAN_FRONTEND=noninteractive \
      apt-get install -y --no-install-recommends "${packages[@]}"
    ;;
  dnf | yum)
    # `dnf install` leaves installed packages alone, so upgrade those separately
    local pkg missing=() present=()
    for pkg in "${packages[@]}"; do
      if rpm -q "$pkg" &>/dev/null; then
        present+=("$pkg")
      else
        missing+=("$pkg")
      fi
    done
    debug "Missing: ${missing[*]:-none}; already installed: ${present[*]:-none}"

    if [[ ${#missing[@]} -gt 0 ]]; then
      run_as_admin "$pm" install -y "${missing[@]}"
    fi
    if [[ "${CONFIG[UPGRADE]}" == "true" && ${#present[@]} -gt 0 ]]; then
      run_as_admin "$pm" upgrade -y "${present[@]}"
    fi
    ;;
  brew)
    brew install "${packages[@]}"
    ;;
  pacman)
    # Arch doesn't support partial upgrades, so sync and upgrade together
    run_as_admin pacman -Syu --needed --noconfirm "${packages[@]}"
    ;;
  *)
    die "Unsupported package manager: $pm"
    ;;
  esac
}
