#!/bin/bash
# modules/editor.sh - Editor stack installation

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
