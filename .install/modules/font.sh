#!/bin/bash
# modules/font.sh - Nerd Font installation

# The user's font directory, or the system one with --system-wide
nerd_font_dir() {
  if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
    echo "/usr/local/share/fonts/${CONFIG[NERD_FONT]}"
  else
    echo "$(get_user_home)/.local/share/fonts/${CONFIG[NERD_FONT]}"
  fi
}

# The release tag the installed font came from, kept in a .version file next
# to it. A font installed some other way has none, so it gets reinstalled here.
nerd_font_installed_version() {
  local file
  file="$(nerd_font_dir)/.version"
  [[ -f "$file" ]] && cat "$file"
}

install_nerd_font() {
  local font="${CONFIG[NERD_FONT]}"
  # The name ends up in a URL and a path
  [[ "$font" =~ ^[A-Za-z0-9-]+$ ]] || die "Invalid Nerd Font name: $font"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    install_nerd_font_cask "$font"
    return
  fi

  should_install "$font Nerd Font" nerd_font_installed_version github_latest_version ryanoasis/nerd-fonts || return 0

  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    warn "No DISPLAY or WAYLAND_DISPLAY is set. A font only helps on the machine that runs your terminal, so over SSH or in a container, install it there instead."
  fi

  local tag url sums tmp_dir dir as pm packages=()
  tag=$(github_latest_version ryanoasis/nerd-fonts) || die "Could not resolve the latest Nerd Fonts release"
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/${tag}/${font}.tar.xz"
  debug "Nerd Font download URL: $url"

  # SHA-256.txt has a "<sha256>  <file>" line for every font in the release,
  # so a name that isn't there is a font that doesn't exist
  sums=$(curl -fsSL "${url%/*}/SHA-256.txt") || die "Failed to download the Nerd Fonts checksums"
  if ! awk -v f="${font}.tar.xz" '$2 == f {found = 1} END {exit !found}' <<<"$sums"; then
    die "No Nerd Font named '$font' in $tag. Names are case-sensitive; see https://www.nerdfonts.com/font-downloads"
  fi

  pm=$(get_package_manager)
  command_exists fc-cache || packages+=(fontconfig)
  if ! command_exists xz; then
    case "$pm" in
    apt) packages+=(xz-utils) ;;
    *) packages+=(xz) ;;
    esac
  fi
  if [[ ${#packages[@]} -gt 0 ]]; then
    install_packages "${packages[@]}"
  fi

  tmp_dir=$(run_as_user mktemp -d)
  run_as_user curl -fL "$url" -o "${tmp_dir}/font.tar.xz" || die "Failed to download the $font Nerd Font"
  verify_sha256 "${tmp_dir}/font.tar.xz" \
    "$(awk -v f="${font}.tar.xz" '$2 == f {print $1}' <<<"$sums")"

  dir=$(nerd_font_dir)
  if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
    as=run_as_admin
  else
    as=run_as_user
  fi
  # Start clean, so an upgrade doesn't leave files the new release dropped
  $as rm -rf "$dir"
  $as mkdir -p "$dir"
  $as tar -C "$dir" -xJf "${tmp_dir}/font.tar.xz" || die "Failed to extract the $font Nerd Font"
  rm -rf "$tmp_dir"

  $as fc-cache -f "$dir"
  if ! run_as_user fc-list : file | grep -F "${dir}/" >/dev/null; then
    die "fontconfig doesn't list the fonts in $dir"
  fi
  # Only now, so a failed install isn't skipped on the next run
  printf '%s\n' "$tag" | $as tee "${dir}/.version" >/dev/null
  info "$font Nerd Font $tag installed in $dir. Pick it in your terminal's font settings."
}

# Homebrew names the casks font-<name>-nerd-font, in lower case
install_nerd_font_cask() {
  local cask="font-${1,,}-nerd-font"

  if ! brew list --cask "$cask" &>/dev/null; then
    info "Installing $cask..."
    brew install --cask "$cask"
  elif [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
    brew upgrade --cask "$cask"
  else
    info "$cask already installed"
  fi
}
