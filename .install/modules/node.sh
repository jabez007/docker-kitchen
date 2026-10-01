#!/bin/bash
# modules/node.sh - Node.js stack installation

# Run a command in a bash (as the real user) that has nvm loaded;
# nvm is a shell function, so it can't be called directly from here
nvm_run() {
  run_as_user bash -c "source '$(get_user_home)/.nvm/nvm.sh' && $1"
}

nvm_installed_version() {
  nvm_run 'nvm --version'
}

# The nvm-managed default; prints nothing for "none" or a system Node
node_installed_version() {
  local current
  current=$(nvm_run 'nvm current')
  if [[ "$current" == v* ]]; then
    echo "$current"
  fi
}

node_latest_lts_version() {
  nvm_run 'nvm version-remote --lts'
}

deno_installed_version() {
  local deno_bin
  deno_bin="$(get_user_home)/.deno/bin/deno"
  [[ -x "$deno_bin" ]] || deno_bin=$(command -v deno) || return 0
  "$deno_bin" --version | awk 'NR==1 {print $2}'
}

install_node_stack() {
  info "Installing Node.js stack (NVM, Node, Deno)..."

  local user_home
  user_home=$(get_user_home)

  # Install NVM. Re-running its installer on an existing install checks out the new tag.
  if should_install NVM nvm_installed_version github_latest_version nvm-sh/nvm; then
    local nvm_version
    nvm_version=$(github_latest_version nvm-sh/nvm) || true
    if [[ ! "$nvm_version" =~ ^v[0-9] ]]; then
      die "Failed to retrieve a valid NVM version (got: '$nvm_version')"
    fi

    run_as_user bash -c \
      "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh | bash" ||
      die "NVM installation failed"
  fi

  # Install the latest LTS and make it the default. Upgrades carry over global packages;
  # older versions stay installed (remove them with `nvm uninstall <version>`).
  local node_before
  node_before=$(node_installed_version 2>/dev/null || true)
  if should_install Node.js node_installed_version node_latest_lts_version; then
    if [[ -n "$node_before" ]]; then
      nvm_run "nvm install --lts --reinstall-packages-from='$node_before'" ||
        die "Node.js upgrade failed"
    else
      nvm_run 'nvm install --lts' || die "Node.js installation failed"
    fi
    nvm_run "nvm alias default 'lts/*'" >/dev/null
  fi

  # Install Deno. A new release replaces the binary in place.
  if ! command_exists unzip; then
    install_packages unzip
  fi
  if should_install Deno deno_installed_version github_latest_version denoland/deno; then
    install_deno
    update_path "$user_home/.deno/bin" "Deno binaries"
  fi

  # Configure Fish for NVM if Fish is available
  if command_exists fish; then
    configure_fish_nvm
    configure_fish_node_path
  fi
}

# nvm puts Node on Fish's PATH only after `nvm use`, so a new Fish has no
# node, npm or global npm commands (codex, opencode, pi). This puts the
# default Node's bin directory on it from conf.d. The path names the Node
# version, so each run rewrites it; after `nvm alias default <version>`,
# run install.sh node again.
# It sets PATH rather than calling fish_add_path -g, which would leave a
# global fish_user_paths that hides the universal one update_path adds to.
configure_fish_node_path() {
  local node bin conf
  node=$(nvm_run 'nvm which default' 2>/dev/null) || return 0
  bin="${node%/node}"
  conf="$(get_user_home)/.config/fish/conf.d/nvm_default.fish"

  run_as_user mkdir -p "${conf%/*}"
  printf '# Written by install.sh: the default Node from nvm\ncontains -- %q $PATH; or set -gx PATH %q $PATH\n' "$bin" "$bin" |
    run_as_user tee "$conf" >/dev/null
  debug "Fish gets Node from $bin"
}

# Install Deno into ~/.deno/bin, where its own installer puts it, from the
# release zip checked against the .sha256sum file published next to it. The
# user downloads and unzips it, since under sudo they can't read root's
# temp dir.
install_deno() {
  local target tag url tmp_dir sum deno_bin
  deno_bin="$(get_user_home)/.deno/bin"

  case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) target="x86_64-unknown-linux-gnu" ;;
  Linux-aarch64 | Linux-arm64) target="aarch64-unknown-linux-gnu" ;;
  Darwin-x86_64) target="x86_64-apple-darwin" ;;
  Darwin-arm64) target="aarch64-apple-darwin" ;;
  *) die "Unsupported platform for Deno: $(uname -s) $(uname -m)" ;;
  esac

  tag=$(github_latest_version denoland/deno) || die "Could not resolve the latest Deno release"
  url="https://github.com/denoland/deno/releases/download/${tag}/deno-${target}.zip"
  debug "Deno download URL: $url"

  tmp_dir=$(run_as_user mktemp -d)
  run_as_user curl -fL "$url" -o "${tmp_dir}/deno.zip" || die "Failed to download Deno"
  # "<sha256>  deno-<target>.zip"
  sum=$(curl -fsSL "${url}.sha256sum") || die "Failed to download the Deno checksum"
  verify_sha256 "${tmp_dir}/deno.zip" "${sum%%[[:space:]]*}"

  run_as_user mkdir -p "$deno_bin"
  run_as_user unzip -o -q "${tmp_dir}/deno.zip" deno -d "$deno_bin" || die "Failed to extract Deno"
  run_as_user chmod 0755 "${deno_bin}/deno"
  rm -rf "$tmp_dir"
}

configure_fish_nvm() {
  info "Configuring Fish shell for NVM..."

  local user_home
  user_home=$(get_user_home)

  # Install Fisher if not present
  if ! run_as_user fish -c "functions -q fisher" 2>/dev/null; then
    info "Installing Fisher..."
    install_fisher
  fi

  # Install Bass plugin for NVM
  run_as_user fish -c 'fisher install edc/bass' 2>/dev/null ||
    warn "Failed to install Bass plugin"

  # Create NVM function for Fish
  local nvm_fish_file="$user_home/.config/fish/functions/nvm.fish"
  if [[ ! -f "$nvm_fish_file" ]]; then
    run_as_user mkdir -p "$(dirname "$nvm_fish_file")"
    run_as_user tee "$nvm_fish_file" >/dev/null <<'EOF'
function nvm
    bass source ~/.nvm/nvm.sh --no-use ';' nvm $argv
end
EOF
    info "NVM configured for Fish shell"
  fi
}

# Install Fisher from its latest release tag. fish_plugins records it as
# jorgebucaran/fisher@<tag>, so `fisher update` refetches that tag instead of
# main; pin_fisher_to_latest moves it to a newer one.
install_fisher() {
  local tag
  tag=$(github_latest_version jorgebucaran/fisher) || die "Could not resolve the latest Fisher release"
  run_as_user fish -c "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/${tag}/functions/fisher.fish | source && fisher install jorgebucaran/fisher@${tag}" ||
    die "Fisher installation failed – aborting Fish/NVM configuration"
}
