#!/bin/bash
# modules/docker.sh - Docker stack installation

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
