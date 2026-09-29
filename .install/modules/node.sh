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

  # Install Deno. Its installer replaces an existing install with the latest release.
  if ! command_exists unzip; then
    install_packages unzip
  fi
  if should_install Deno deno_installed_version github_latest_version denoland/deno; then
    run_as_user bash -c \
      "curl -fsSL https://deno.land/install.sh | sh -s -- -y" ||
      die "Deno installation failed"
    update_path "$user_home/.deno/bin" "Deno binaries"
  fi

  # Configure Fish for NVM if Fish is available
  if command_exists fish; then
    configure_fish_nvm
  fi
}

configure_fish_nvm() {
  info "Configuring Fish shell for NVM..."

  local user_home
  user_home=$(get_user_home)

  # Install Fisher if not present
  if ! run_as_user fish -c "functions -q fisher" 2>/dev/null; then
    info "Installing Fisher..."
    run_as_user fish -c "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" ||
      die "Fisher installation failed – aborting Fish/NVM configuration"
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
