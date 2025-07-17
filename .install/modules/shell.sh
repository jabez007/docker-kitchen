#!/bin/bash
# modules/shell.sh - Shell stack installation

install_shell_stack() {
  info "Installing shell stack (Fish, Tmux, Starship)..."

  # Install Fish and Tmux
  install_packages fish tmux

  # Install Starship
  if ! command_exists starship; then
    info "Installing Starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y ||
      die "Failed to install Starship"
  else
    info "Starship already installed"
  fi

  # Configure shells
  configure_fish_shell
  configure_fish_nvm
  configure_tmux
  configure_starship
  configure_bash_integration
}

configure_fish_shell() {
  info "Configuring Fish shell..."

  local user_home
  user_home=$(get_user_home)

  local fish_config="${user_home}/.config/fish/config.fish"
  run_as_user mkdir -p "$(dirname "$fish_config")"

  # Add tmux auto-attach if not present
  if ! grep -q "tmux attach-session -t ${CONFIG[TMUX_SESSION]}" "$fish_config" 2>/dev/null; then
    run_as_user tee -a "$fish_config" >/dev/null <<EOF

# Automatically attach to or create a tmux session
if type -q tmux
    if not set -q TMUX
        if tmux has-session -t ${CONFIG[TMUX_SESSION]} 2>/dev/null
            tmux attach-session -t ${CONFIG[TMUX_SESSION]}
        else
            tmux new-session -s ${CONFIG[TMUX_SESSION]}
        end
    end
end
EOF
    info "Fish configured for tmux auto-attach"
  fi
}

configure_tmux() {
  info "Configuring Tmux..."

  local user_home
  user_home=$(get_user_home)

  local tmux_conf="${user_home}/.tmux.conf"
  local tpm_dir="${user_home}/.tmux/plugins/tpm"

  # Install TPM if not present
  if [[ ! -d "$tpm_dir" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir" ||
      warn "Failed to install TPM"
  fi

  # Configure tmux.conf if not already configured
  if ! grep -q "tmux-plugins/tmux-resurrect" "$tmux_conf" 2>/dev/null; then
    run_as_user tee -a "$tmux_conf" >/dev/null <<'EOF'

# Tmux Plugin Manager and plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'

# Initialize TPM (keep this line at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
EOF
    info "Tmux configuration updated"
  fi
}

configure_starship() {
  info "Configuring Starship prompt..."

  local user_home
  user_home=$(get_user_home)

  local starship_config="${user_home}/.config/starship.toml"
  run_as_user mkdir -p "$(dirname "$starship_config")"

  # Apply preset
  run_as_user starship preset "${CONFIG[STARSHIP_PRESET]}" -o "$starship_config" ||
    warn "Failed to apply Starship preset: ${CONFIG[STARSHIP_PRESET]}"

  # Add to Fish config
  local fish_config="${user_home}/.config/fish/config.fish"
  if ! grep -q 'starship init fish' "$fish_config" 2>/dev/null; then
    run_as_user bash -c 'echo "starship init fish | source" >>"'"$fish_config"'"'
  fi

  # Add to bashrc
  local bashrc="${user_home}/.bashrc"
  if ! grep -q 'starship init bash' "$bashrc" 2>/dev/null; then
    run_as_user tee -a "$bashrc" >/dev/null <<'EOF'

# Initialize Starship for Bash
eval "$(starship init bash)"
EOF
  fi
}

configure_bash_integration() {
  info "Configuring Bash to Fish integration..."

  local user_home
  user_home=$(get_user_home)

  local bashrc="${user_home}/.bashrc"

  if ! grep -q "exec fish" "$bashrc" 2>/dev/null; then
    run_as_user tee -a "$bashrc" >/dev/null <<'EOF'

# Launch fish shell automatically unless bash was started from fish
if command -v fish &> /dev/null && [[ $- == *i* ]]; then
    parent_process=$(ps -o comm= -p $(ps -o ppid= -p $$))
    if [[ "$parent_process" != "fish" ]]; then
        exec fish
    fi
fi
EOF
    info "Bash configured to launch Fish automatically"
  fi
}
