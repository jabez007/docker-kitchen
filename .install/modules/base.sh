#!/bin/bash
# modules/base.sh - Base dependencies installation

install_base_dependencies() {
  info "Installing base dependencies..."

  local packages=(
    bash curl git
    unzip ca-certificates
    ripgrep jq
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
