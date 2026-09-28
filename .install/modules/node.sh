#!/bin/bash
# modules/node.sh - Node.js stack installation

install_node_stack() {
  info "Installing Node.js stack (NVM, Node, Deno)..."

  local user_home nvm_sh
  user_home=$(get_user_home)
  nvm_sh="${user_home}/.nvm/nvm.sh"

  # Install NVM
  if [[ ! -s "$nvm_sh" ]]; then
    info "Installing NVM..."
    local nvm_version
    if command_exists jq; then
      nvm_version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name)
    else
      nvm_version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
    fi

    # Validate nvm_version
    if [[ -z "$nvm_version" ]] || [[ "$nvm_version" == "null" ]] || [[ ! "$nvm_version" =~ ^v ]]; then
      die "Failed to retrieve a valid NVM version (got: '$nvm_version')"
    fi

    run_as_user bash -c \
      "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh | bash" ||
      die "NVM installation failed"
  else
    info "NVM already installed"
  fi

  # nvm is a shell function, so check for and install Node in a bash that sources it
  if ! run_as_user bash -c "source '$nvm_sh' && command -v node" >/dev/null 2>&1; then
    info "Installing Node.js LTS..."
    run_as_user bash -c "source '$nvm_sh' && nvm install --lts" ||
      die "Node.js installation failed"
  else
    info "Node.js already installed"
  fi

  # Install Deno
  if ! command_exists unzip; then
    install_packages unzip
  fi
  if [[ ! -x "${user_home}/.deno/bin/deno" ]] && ! command_exists deno; then
    info "Installing Deno..."
    run_as_user bash -c \
      "curl -fsSL https://deno.land/install.sh | sh -s -- -y" ||
      die "Deno installation failed"
    update_path "$user_home/.deno/bin" "Deno binaries"
  else
    info "Deno already installed"
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
