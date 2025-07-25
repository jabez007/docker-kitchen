#!/bin/bash
# modules/config.sh - User configs installation

install_user_configs() {
  info "Installing user configurations..."

  # Ensure git is present before using or configuring it
  if ! command_exists git; then
    warn "Git not found – installing base dependencies"
    install_base_dependencies # guarantees git
  fi

  # Configure git with best practices
  setup_git_config

  if command_exists nvim; then
    # Install AstroNvim config
    install_astronvim_config
  fi

  info "User configurations installed successfully"
}

setup_git_config() {
  info "Setting up git configuration with best practices..."

  # Always operate as the actual (non-root) user
  local git_cfg=(git config --global)
  if [[ "$IS_ROOT" == "true" ]]; then
    git_cfg=(run_as_user git config --global)
  fi

  # Core settings
  "${git_cfg[@]}" init.defaultBranch main
  "${git_cfg[@]}" core.autocrlf input
  "${git_cfg[@]}" core.safecrlf true
  "${git_cfg[@]}" pull.rebase true
  "${git_cfg[@]}" push.default simple
  "${git_cfg[@]}" fetch.prune true
  "${git_cfg[@]}" rebase.autoStash true

  # Better diff and merge tools
  "${git_cfg[@]}" diff.algorithm patience
  "${git_cfg[@]}" merge.conflictstyle diff3
  "${git_cfg[@]}" rerere.enabled true

  # Security and performance
  "${git_cfg[@]}" transfer.fsckobjects true
  "${git_cfg[@]}" fetch.fsckobjects true
  "${git_cfg[@]}" receive.fsckObjects true
  "${git_cfg[@]}" gc.auto 1

  # Better output formatting
  "${git_cfg[@]}" color.ui auto
  "${git_cfg[@]}" branch.sort -committerdate
  "${git_cfg[@]}" tag.sort version:refname

  # Useful aliases
  "${git_cfg[@]}" alias.st status
  "${git_cfg[@]}" alias.co checkout
  "${git_cfg[@]}" alias.br branch
  "${git_cfg[@]}" alias.ci commit
  "${git_cfg[@]}" alias.unstage 'reset HEAD --'
  "${git_cfg[@]}" alias.last 'log -1 HEAD'
  "${git_cfg[@]}" alias.visual '!gitk'
  "${git_cfg[@]}" alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

  # Only set user info if not already configured
  if ! "${git_cfg[@]}" user.name &>/dev/null; then
    if [[ -n "${CONFIG[GIT_USER_NAME]:-}" ]]; then
      "${git_cfg[@]}" user.name "${CONFIG[GIT_USER_NAME]}"
      info "Git user.name set to: ${CONFIG[GIT_USER_NAME]}"
    else
      warn "Git user.name not configured - set CONFIG[GIT_USER_NAME] or run 'git config --global user.name \"Your Name\"'"
    fi
  fi

  if ! "${git_cfg[@]}" user.email &>/dev/null; then
    if [[ -n "${CONFIG[GIT_USER_EMAIL]:-}" ]]; then
      "${git_cfg[@]}" user.email "${CONFIG[GIT_USER_EMAIL]}"
      info "Git user.email set to: ${CONFIG[GIT_USER_EMAIL]}"
    else
      warn "Git user.email not configured - set CONFIG[GIT_USER_EMAIL] or run 'git config --global user.email \"you@example.com\"'"
    fi
  fi

  info "Git configuration setup completed"
}

install_astronvim_config() {
  info "Installing AstroNvim configuration..."

  local user_home
  user_home=$(get_user_home)

  local config_dir="${user_home}/.config/nvim"

  if [[ -d "$config_dir" ]]; then
    warn "Neovim config directory exists, skipping AstroNvim setup"
    return 0
  fi

  [[ -n "${CONFIG[ASTRONVIM_REPO]:-}" ]] ||
    die "CONFIG[ASTRONVIM_REPO] is empty – specify --astronvim-repo URL"

  git clone --depth 1 "${CONFIG[ASTRONVIM_REPO]}" "$config_dir" ||
    die "Failed to clone AstroNvim config"

  if [[ "${CONFIG[KEEP_GIT]}" != "true" ]]; then
    rm -rf "${config_dir}/.git"
  fi

  info "AstroNvim configuration installed"
}
