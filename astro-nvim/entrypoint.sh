#!/bin/bash
set -euo pipefail

# Function to print colored output
print_status() {
  echo -e "\033[1;34m[NVIM-CONTAINER]\033[0m $1"
}

print_error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

print_success() {
  echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# Function to check if Neovim plugins are installed
check_plugins() {
  local nvim_share_dir="$HOME/.local/share/nvim"
  local lazy_dir="$nvim_share_dir/lazy"

  if [ -d "$lazy_dir" ] && [ "$(ls -A "$lazy_dir" 2>/dev/null)" ]; then
    return 0 # Plugins found
  else
    return 1 # No plugins found
  fi
}

# Function to install plugins
install_plugins() {
  if ! command -v nvim >/dev/null 2>&1; then
    print_error "Neovim binary not found in PATH"
    return 127
  fi

  print_status "Installing Neovim plugins..."

  # Install Lazy and plugins
  if nvim --headless -c "Lazy! sync" -c "qa!"; then
    print_success "Lazy plugins installed successfully"
  else
    print_error "Failed to install Lazy plugins"
    return 1
  fi

  # Install the Mason tools the config lists (mason-tool-installer's ensure_installed)
  print_status "Installing Mason tools..."
  local rc=0
  nvim --headless \
    -c 'if exists(":MasonToolsInstallSync") == 2 | execute "MasonToolsInstallSync" | else | cquit 3 | endif' \
    -c "qa" || rc=$?
  case "$rc" in
  0) print_success "Mason tools installed successfully" ;;
  3) print_status "Config doesn't use mason-tool-installer; skipping Mason tools" ;;
  *)
    print_error "Failed to install Mason tools"
    return 1
    ;;
  esac
}

# Function to handle first-time setup
first_time_setup() {
  print_status "First-time setup detected. This may take a few minutes..."

  # Create necessary directories
  mkdir -p "$HOME/.local/share/nvim" \
    "$HOME/.local/state/nvim" \
    "$HOME/.cache/nvim" \
    "$HOME/.config/lazygit"

  # Install plugins
  if install_plugins; then
    print_success "Setup completed successfully!"
  else
    print_error "Setup failed. Neovim will start but some features may not work."
    return 1
  fi
}

# Main logic
main() {
  print_status "Starting Neovim container..."

  # Maintenance commands run on their own, before any automatic setup
  case "${1:-}" in
  setup)
    print_status "Force setup requested..."
    first_time_setup
    exit $?
    ;;
  clean)
    print_status "Cleaning Neovim data..."
    rm -rf "$HOME/.local/share/nvim/lazy" \
      "$HOME/.local/share/nvim/mason" \
      "$HOME/.local/state/nvim" \
      "$HOME/.cache/nvim"
    print_success "Cleanup completed"
    exit 0
    ;;
  esac

  # Check if this is the first run (no plugins installed)
  if ! check_plugins; then
    # Only run setup if we're not just executing a command
    if { [ "$#" -eq 0 ] || [[ "$1" != -* ]]; } && [ -t 0 ]; then
      # Start Neovim even if setup fails
      first_time_setup || true
    else
      print_status "Non-interactive mode detected, skipping plugin installation"
    fi
  else
    print_status "Plugins already installed, starting quickly..."
  fi

  # Handle different argument patterns
  if [ "$#" -eq 0 ]; then
    # No arguments - start nvim normally
    print_status "Starting Neovim..."
    exec nvim
  elif [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    # Start shell instead of nvim
    print_status "Starting shell..."
    exec "$@"
  else
    # Pass all arguments to nvim
    print_status "Starting Neovim with arguments: $*"
    exec nvim "$@"
  fi
}

# Run main function with all arguments
main "$@"
