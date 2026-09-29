#!/bin/bash
# modules/editor.sh - Editor stack installation

nvim_installed_version() {
  command_exists nvim && nvim --version | awk 'NR==1 {print $2}'
}

lazygit_installed_version() {
  command_exists lazygit && lazygit --version | sed -n 's/.*, version=\([^,]*\).*/\1/p'
}

btm_installed_version() {
  command_exists btm && btm --version | awk 'NR==1 {print $2}'
}

install_editor_stack() {
  info "Installing editor stack (Neovim, LazyGit, Bottom)..."

  # Install Neovim
  if should_install Neovim nvim_installed_version github_latest_version neovim/neovim; then
    local arch nvim_tarball tmp_dir

    arch=$(uname -m)
    case "$arch" in
    x86_64) nvim_tarball="nvim-linux-x86_64" ;;
    aarch64 | arm64) nvim_tarball="nvim-linux-arm64" ;;
    *) die "Unsupported architecture for Neovim: $arch" ;;
    esac

    tmp_dir=$(mktemp -d)
    curl -fL "https://github.com/neovim/neovim/releases/download/stable/${nvim_tarball}.tar.gz" \
      -o "${tmp_dir}/nvim.tar.gz" || die "Failed to download Neovim"

    run_as_admin rm -rf "/opt/${nvim_tarball}"
    run_as_admin tar -C /opt -xzf "${tmp_dir}/nvim.tar.gz" || die "Failed to extract Neovim"
    run_as_admin ln -sf "/opt/${nvim_tarball}/bin/nvim" /usr/local/bin/nvim
    rm -rf "$tmp_dir"

    verify_installation nvim "Neovim"
  fi

  # Install LazyGit
  if should_install LazyGit lazygit_installed_version github_latest_version jesseduffield/lazygit; then
    local lazygit_arch lazygit_url tmp_dir

    # Map uname -m output to LazyGit architecture naming
    case "$(uname -m)" in
    x86_64) lazygit_arch="x86_64" ;;
    aarch64 | arm64) lazygit_arch="arm64" ;;
    armv7l | armv6l | arm*) lazygit_arch="armv6" ;;
    *) die "Unsupported architecture for LazyGit: $(uname -m)" ;;
    esac

    debug "LazyGit architecture: $lazygit_arch"

    local os_name
    os_name=$(uname -s | tr '[:upper:]' '[:lower:]')

    if command_exists jq; then
      lazygit_url=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
        jq -r ".assets[] | select(.name | ascii_downcase | contains(\"$os_name\") and contains(\"$lazygit_arch\") and endswith(\"tar.gz\")) | .browser_download_url" | head -n 1)
    else
      lazygit_url=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
        grep -i "browser_download_url.*lazygit.*$os_name.*${lazygit_arch}.*tar.gz" |
        cut -d : -f 2,3 | tr -d \" | tail -n 1)
    fi
    lazygit_url=$(trim "$lazygit_url")

    debug "LazyGit download URL: $lazygit_url"

    [[ -n "$lazygit_url" ]] || die "Could not resolve LazyGit download URL"

    tmp_dir=$(mktemp -d)
    curl -fL "$lazygit_url" -o "${tmp_dir}/lazygit.tar.gz" || die "Failed to download LazyGit"
    run_as_admin tar -C /usr/local/bin -xzf "${tmp_dir}/lazygit.tar.gz" lazygit
    rm -rf "$tmp_dir"

    verify_installation lazygit "LazyGit"
  fi

  # Install Bottom
  if should_install Bottom btm_installed_version github_latest_version ClementTsang/bottom; then
    local pm bottom_url tmp_dir
    pm=$(get_package_manager)

    # Release assets include musl builds too; take the glibc one
    if [[ "$pm" == "apt" ]]; then
      if command_exists jq; then
        bottom_url=$(curl -fsSL https://api.github.com/repos/ClementTsang/bottom/releases/latest |
          jq -r ".assets[] | select(.name | contains(\"$(dpkg --print-architecture)\") and endswith(\"deb\") and (contains(\"musl\") | not)) | .browser_download_url" | head -n 1)
      else
        bottom_url=$(curl -fsSL https://api.github.com/repos/ClementTsang/bottom/releases/latest |
          grep "browser_download_url.*bottom.*$(dpkg --print-architecture).*deb" |
          grep -v "musl" |
          cut -d : -f 2,3 | tr -d \" | tail -n 1)
      fi
      bottom_url=$(trim "$bottom_url")

      debug "Bottom download URL: $bottom_url"

      if [[ -n "$bottom_url" ]]; then
        tmp_dir=$(mktemp -d)
        curl -fL "$bottom_url" -o "${tmp_dir}/bottom.deb"
        run_as_admin apt-get install -y "${tmp_dir}/bottom.deb"
        rm -rf "$tmp_dir"
      else
        warn "Could not install Bottom via deb package"
      fi
    elif [[ "$pm" == "dnf" ]]; then
      if command_exists jq; then
        bottom_url=$(curl -fsSL https://api.github.com/repos/ClementTsang/bottom/releases/latest |
          jq -r ".assets[] | select(.name | contains(\"$(rpm --eval '%{_arch}')\") and endswith(\"rpm\") and (contains(\"musl\") | not)) | .browser_download_url" | head -n 1)
      else
        bottom_url=$(curl -fsSL https://api.github.com/repos/ClementTsang/bottom/releases/latest |
          grep "browser_download_url.*bottom.*$(rpm --eval '%{_arch}').*rpm" |
          grep -v "musl" |
          cut -d : -f 2,3 | tr -d \" | tail -n 1)
      fi
      bottom_url=$(trim "$bottom_url")

      debug "Bottom download URL: $bottom_url"

      if [[ -n "$bottom_url" ]]; then
        tmp_dir=$(mktemp -d)
        curl -fL "$bottom_url" -o "${tmp_dir}/bottom.rpm"
        run_as_admin dnf install -y "${tmp_dir}/bottom.rpm"
        rm -rf "$tmp_dir"
      else
        warn "Could not install Bottom via rpm package"
      fi
    else
      # Try package manager
      case "$pm" in
      brew | pacman) install_packages bottom ;;
      *) warn "Bottom not available via $pm, skipping..." ;;
      esac
    fi

    verify_installation btm "Bottom"
  fi

  info "Editor stack installation complete. Use 'config' component to install AstroNvim configuration."
}
