#!/bin/bash
# modules/docker.sh - Docker stack installation

install_docker_stack() {
  info "Installing Docker..."

  local pm os
  pm=$(get_package_manager)
  os=$(detect_system | cut -d: -f1)

  if command_exists docker && [[ "${CONFIG[UPGRADE]}" != "true" ]]; then
    info "Docker already installed"
    return 0
  fi

  if command_exists docker && [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
    info "Docker is already installed. Using $pm to check for updates via official repositories..."
  fi

  case "$pm" in
  apt)
    # Ubuntu/Debian Docker installation
    [[ -f /etc/os-release ]] || die "/etc/os-release not found"
    source /etc/os-release

    local docker_distro="$ID"
    if [[ "$docker_distro" != "debian" ]] && [[ "$docker_distro" != "ubuntu" ]]; then
      for like in ${ID_LIKE:-}; do
        if [[ "$like" == "debian" ]] || [[ "$like" == "ubuntu" ]]; then
          docker_distro="$like"
          break
        fi
      done
    fi

    if [[ "$docker_distro" != "debian" ]] && [[ "$docker_distro" != "ubuntu" ]]; then
      die "Docker installation (apt) only supports 'debian' or 'ubuntu' families. Detected ID: '$ID', ID_LIKE: '${ID_LIKE:-none}', mapped to: '$docker_distro'."
    fi

    # Determine the distribution codename
    local docker_codename="${VERSION_CODENAME:-}"
    
    # For derivatives, override with upstream codename if available
    if [[ "$ID" != "$docker_distro" ]]; then
      if [[ -n "${UBUNTU_CODENAME:-}" ]]; then
        docker_codename="$UBUNTU_CODENAME"
      elif [[ -n "${DEBIAN_CODENAME:-}" ]]; then
        docker_codename="$DEBIAN_CODENAME"
      fi
    fi

    # Fallback to lsb_release if still empty
    if [[ -z "$docker_codename" ]] && command_exists lsb_release; then
      docker_codename=$(lsb_release -cs)
    fi

    if [[ -z "$docker_codename" ]] || [[ "$docker_codename" == "stable" ]]; then
      die "Could not determine a valid distribution codename for Docker repository (found: '${docker_codename:-none}')."
    fi

    if ! command_exists docker || [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
      run_as_admin apt update
      run_as_admin apt install -y ca-certificates curl gnupg
      run_as_admin install -m 0755 -d /etc/apt/keyrings

      curl -fsSL "https://download.docker.com/linux/${docker_distro}/gpg" |
        run_as_admin gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      run_as_admin chmod a+r /etc/apt/keyrings/docker.gpg

      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${docker_distro} ${docker_codename} stable" |
        run_as_admin tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi

    run_as_admin apt update
    run_as_admin apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run_as_admin systemctl enable --now docker
    ;;
  dnf)
    # Fedora/RHEL Docker installation
    [[ -f /etc/os-release ]] || die "/etc/os-release not found"
    source /etc/os-release

    local repo_family="fedora"
    if [[ "$ID" != "fedora" ]]; then
      # Check for RHEL family
      local is_rhel=false
      for like in $ID $ID_LIKE; do
        if [[ "$like" =~ ^(rhel|centos|fedora)$ ]]; then
          [[ "$like" == "fedora" ]] || repo_family="rhel"
          is_rhel=true
          break
        fi
      done
      [[ "$is_rhel" == "true" ]] || die "Docker installation (dnf) only supports Fedora or RHEL-based families. Detected ID: '$ID', ID_LIKE: '${ID_LIKE:-none}'."
    fi

    if ! command_exists docker || [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
      run_as_admin dnf -y install dnf-plugins-core
      run_as_admin dnf config-manager --add-repo "https://download.docker.com/linux/${repo_family}/docker-ce.repo"
    fi
    run_as_admin dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run_as_admin systemctl start docker
    run_as_admin systemctl enable docker
    ;;
  brew)
    # macOS Docker installation
    if [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
      brew upgrade --cask docker || brew install --cask docker
    else
      brew install --cask docker
    fi
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
