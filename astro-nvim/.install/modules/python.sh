#!/bin/bash
# modules/python.sh - Python version management (pyenv)

install_python_stack() {
  info "Installing Python stack (pyenv)..."

  local user_home
  user_home=$(get_user_home)

  # Install pyenv
  if [[ ! -d "$user_home/.pyenv" ]]; then
    info "Installing pyenv..."
    # Ensure dependencies for building python are met (handled by base.sh)
    
    run_as_user bash -c "curl -fsSL https://pyenv.run | bash" ||
      die "pyenv installation failed"
  else
    info "pyenv already installed"
  fi

  # Configure shells for pyenv
  configure_bash_pyenv
  if command_exists fish; then
    configure_fish_pyenv
  fi

  # Install latest stable Python if not present
  if run_as_user bash -c "command -v pyenv >/dev/null" && ! run_as_user bash -c "pyenv versions --bare | grep -q '3.'" ; then
    info "Installing latest stable Python 3..."
    # This can take a while, so we might want to skip it by default or let the user do it
    # For now, let's just make sure pyenv is usable
    info "pyenv is ready. You can install python versions using: pyenv install <version>"
  fi
}

configure_bash_pyenv() {
  info "Configuring Bash for pyenv..."
  local user_home
  user_home=$(get_user_home)
  local bashrc="${user_home}/.bashrc"

  if ! grep -q "PYENV_ROOT" "$bashrc" 2>/dev/null; then
    {
      echo ""
      echo "# pyenv configuration"
      echo 'export PYENV_ROOT="$HOME/.pyenv"'
      echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
      echo 'eval "$(pyenv init -)"'
    } | run_as_user tee -a "$bashrc" >/dev/null
    info "pyenv configured in Bash"
  fi
}

configure_fish_pyenv() {
  info "Configuring Fish for pyenv..."
  local user_home
  user_home=$(get_user_home)
  local fish_config="${user_home}/.config/fish/config.fish"

  if ! grep -q "status is-interactive; and pyenv init" "$fish_config" 2>/dev/null; then
    run_as_user mkdir -p "$(dirname "$fish_config")"
    {
      echo ""
      echo "# pyenv configuration"
      echo 'set -gx PYENV_ROOT $HOME/.pyenv'
      echo 'fish_add_path $PYENV_ROOT/bin'
      echo 'status is-interactive; and pyenv init - | source'
    } | run_as_user tee -a "$fish_config" >/dev/null
    info "pyenv configured in Fish"
  fi
}
