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

# Install packages based on package manager
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
  dnf)
    local pkg
    for pkg in "${packages[@]}"; do
      if ! rpm -q "$pkg" &>/dev/null; then
        debug "Installing $pkg..."
        run_as_admin dnf install -y "$pkg"
      else
        info "$pkg is already installed"
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
    # Arch doesn't support partial upgrades, so sync and upgrade together
    run_as_admin pacman -Syu --needed --noconfirm "${packages[@]}"
    ;;
  *)
    die "Unsupported package manager: $pm"
    ;;
  esac
}
