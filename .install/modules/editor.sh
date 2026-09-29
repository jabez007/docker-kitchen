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

    lazygit_url=$(github_release_asset_url jesseduffield/lazygit \
      "/lazygit_[^/]*_${os_name}_${lazygit_arch}\.tar\.gz$") ||
      die "Could not resolve LazyGit download URL"

    debug "LazyGit download URL: $lazygit_url"

    tmp_dir=$(mktemp -d)
    curl -fL "$lazygit_url" -o "${tmp_dir}/lazygit.tar.gz" || die "Failed to download LazyGit"

    # Each release has a checksums.txt with a "<sha256>  <asset name>" line per asset
    local lazygit_sums
    lazygit_sums=$(curl -fsSL "${lazygit_url%/*}/checksums.txt") ||
      die "Failed to download LazyGit checksums"
    verify_sha256 "${tmp_dir}/lazygit.tar.gz" \
      "$(awk -v f="${lazygit_url##*/}" '$2 == f {print $1}' <<<"$lazygit_sums")"

    run_as_admin tar -C /usr/local/bin -xzf "${tmp_dir}/lazygit.tar.gz" lazygit
    rm -rf "$tmp_dir"

    verify_installation lazygit "LazyGit"
  fi

  # Install Bottom
  if should_install Bottom btm_installed_version github_latest_version ClementTsang/bottom; then
    local pm bottom_url tmp_dir
    pm=$(get_package_manager)

    # Release assets include musl builds too (bottom-musl_*); the patterns take the glibc one
    if [[ "$pm" == "apt" ]]; then
      bottom_url=$(github_release_asset_url ClementTsang/bottom \
        "/bottom_[^/]*_$(dpkg --print-architecture)\.deb$") || true

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
      bottom_url=$(github_release_asset_url ClementTsang/bottom \
        "/bottom-[0-9][^/]*\.$(rpm --eval '%{_arch}')\.rpm$") || true

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
