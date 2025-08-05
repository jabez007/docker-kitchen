#!/bin/bash
# modules/node.sh - Node.js stack installation

install_node_stack() {
  info "Installing Node.js stack (NVM, Node, Deno)..."

  local user_home
  user_home=$(get_user_home)

  # Install NVM
  if [[ ! -s "$user_home/.nvm/nvm.sh" ]]; then
    info "Installing NVM..."
    local nvm_version
    nvm_version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest |
      grep '"tag_name"' | cut -d '"' -f 4)

    run_as_user bash -c \
      "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh | bash" ||
      die "NVM installation failed"

    export NVM_DIR="${user_home}/.nvm"
    # shellcheck disable=SC1091
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  else
    info "NVM already installed"
    export NVM_DIR="${user_home}/.nvm"
    # shellcheck disable=SC1091
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  fi

  # Install latest LTS Node.js
  if ! run_as_user command_exists node; then
    info "Installing Node.js LTS..."
    run_as_user bash -c \
      "source $user_home/.nvm/nvm.sh && nvm install --lts" ||
      die "Node.js installation failed"
  fi

  # Install Deno
  if ! command_exists unzip; then
    install_packages unzip
  fi
  if ! command_exists deno; then
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
  local fisher_path="$user_home/.config/fish/functions/fisher.fish"
  if [[ ! -f "$fisher_path" ]]; then
    run_as_user bash -c \
      "curl -sL https://git.io/fisher --create-dirs -o \"$fisher_path\"" ||
      die "Fisher installation failed – aborting Fish/NVM configuration"
  fi

  # Install Bass plugin for NVM
  if command_exists fish && [[ -f "$fisher_path" ]]; then
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
  fi
}
