#!/bin/bash
# modules/shell.sh - Shell stack installation

starship_installed_version() {
  command_exists starship && starship --version | awk 'NR==1 {print $2}'
}

install_shell_stack() {
  info "Installing shell stack (Fish, Tmux, Starship)..."

  # Install Fish and Tmux
  install_packages fish tmux

  # Install Starship
  if should_install Starship starship_installed_version github_latest_version starship/starship; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y ||
      die "Failed to install Starship"
  fi

  # Configure shells
  configure_fish_shell
  configure_tmux
  configure_starship
  configure_bash_integration

  # Hook up tools that were installed before Fish existed
  local user_home
  user_home=$(get_user_home)
  if [[ -s "${user_home}/.nvm/nvm.sh" ]]; then
    configure_fish_nvm
  fi
  if [[ -d "${user_home}/.pyenv" ]]; then
    configure_fish_pyenv
  fi

  # Fisher manages the Fish plugins (bass for NVM)
  if [[ "${CONFIG[UPGRADE]}" == "true" ]] && run_as_user fish -c "functions -q fisher" 2>/dev/null; then
    info "Updating Fish plugins..."
    run_as_user fish -c "fisher update" || warn "Failed to update Fish plugins"
  fi
}

configure_fish_shell() {
  info "Configuring Fish shell..."

  local user_home
  user_home=$(get_user_home)

  local fish_config="${user_home}/.config/fish/config.fish"
  run_as_user mkdir -p "$(dirname "$fish_config")"

  # Add tmux auto-attach if not present. The is-interactive guard keeps
  # `fish -c ...` (used by this script and others) from starting tmux.
  if ! grep -q "tmux attach-session -t ${CONFIG[TMUX_SESSION]}" "$fish_config" 2>/dev/null; then
    run_as_user tee -a "$fish_config" >/dev/null <<EOF

# Automatically attach to or create a tmux session
if status is-interactive; and type -q tmux; and not set -q TMUX
    if tmux has-session -t ${CONFIG[TMUX_SESSION]} 2>/dev/null
        tmux attach-session -t ${CONFIG[TMUX_SESSION]}
    else
        tmux new-session -s ${CONFIG[TMUX_SESSION]}
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

  # Install TPM if not present. Its plugins update from inside tmux (prefix + U).
  if [[ ! -d "$tpm_dir" ]]; then
    run_as_user git clone https://github.com/tmux-plugins/tpm "$tpm_dir" ||
      warn "Failed to install TPM"
  elif [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
    info "Updating TPM..."
    run_as_user git -C "$tpm_dir" pull --ff-only || warn "Failed to update TPM"
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

  # Apply the preset only once, so re-runs (including --upgrade) keep your edits
  if [[ ! -f "$starship_config" ]]; then
    run_as_user starship preset "${CONFIG[STARSHIP_PRESET]}" -o "$starship_config" ||
      warn "Failed to apply Starship preset: ${CONFIG[STARSHIP_PRESET]}"
  else
    info "Keeping existing $starship_config (delete it to apply the '${CONFIG[STARSHIP_PRESET]}' preset)"
  fi

  # Add to Fish config
  local fish_config="${user_home}/.config/fish/config.fish"
  if ! grep -q 'starship init fish' "$fish_config" 2>/dev/null; then
    echo "starship init fish | source" | run_as_user tee -a "$fish_config" >/dev/null
    info "Starship initialized in Fish config"
  fi

  # Add to bashrc
  local bashrc="${user_home}/.bashrc"
  if ! grep -q 'starship init bash' "$bashrc" 2>/dev/null; then
    {
      echo ""
      echo "# Initialize Starship for Bash"
      echo 'eval "$(starship init bash)"'
    } | run_as_user tee -a "$bashrc" >/dev/null
    info "Starship initialized in Bash config"
  fi
}

configure_bash_integration() {
  info "Configuring Bash to Fish integration..."

  local user_home
  user_home=$(get_user_home)

  local bashrc="${user_home}/.bashrc"

  if ! grep -q "exec fish" "$bashrc" 2>/dev/null; then
    {
      echo ""
      echo "# Launch fish shell automatically unless bash was started from fish"
      echo 'if command -v fish &> /dev/null && [[ $- == *i* ]]; then'
      echo '    parent_process=$(ps -o comm= -p $(ps -o ppid= -p $$))'
      echo '    if [[ "$parent_process" != "fish" ]]; then'
      echo '        exec fish'
      echo '    fi'
      echo 'fi'
    } | run_as_user tee -a "$bashrc" >/dev/null
    info "Bash configured to launch Fish automatically"
  fi
}
