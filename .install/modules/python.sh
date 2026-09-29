#!/bin/bash
# modules/python.sh - Python version management (pyenv)

install_python_stack() {
  info "Installing Python stack (pyenv)..."

  local user_home
  user_home=$(get_user_home)

  install_python_build_deps

  # Install pyenv
  if [[ ! -d "$user_home/.pyenv" ]]; then
    info "Installing pyenv..."
    run_as_user bash -c "curl -fsSL https://pyenv.run | bash" ||
      die "pyenv installation failed"
  elif [[ "${CONFIG[UPGRADE]}" == "true" ]]; then
    # pyenv is a git checkout; `pyenv update` (from pyenv.run) also updates its plugins
    info "Updating pyenv..."
    run_as_user "$user_home/.pyenv/bin/pyenv" update ||
      run_as_user git -C "$user_home/.pyenv" pull --ff-only ||
      die "pyenv update failed"
  else
    info "pyenv already installed"
  fi

  # Configure shells for pyenv
  configure_bash_pyenv
  if command_exists fish; then
    configure_fish_pyenv
  fi

  # Building an interpreter takes minutes, so leave that to the user
  info "pyenv is ready. Open a new shell and run: pyenv install 3"
}

# Headers pyenv needs to build a complete CPython (see pyenv's wiki)
install_python_build_deps() {
  local pm packages=()
  pm=$(get_package_manager)
  case "$pm" in
  apt)
    packages=(
      build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev
      libsqlite3-dev libncurses-dev xz-utils tk-dev libxml2-dev
      libxmlsec1-dev libffi-dev liblzma-dev
    )
    ;;
  dnf | yum)
    packages=(
      make gcc patch zlib-devel bzip2 bzip2-devel readline-devel
      sqlite sqlite-devel openssl-devel tk-devel libffi-devel
      xz-devel libuuid-devel gdbm-devel ncurses-devel
    )
    ;;
  pacman)
    packages=(base-devel openssl zlib xz tk)
    ;;
  brew)
    packages=(openssl readline sqlite3 xz tcl-tk zlib)
    ;;
  *)
    warn "Unknown package manager '$pm'; install Python build dependencies yourself"
    return 0
    ;;
  esac
  install_packages "${packages[@]}"
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
