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
  print_status "Installing Neovim plugins..."

  # Install Lazy and plugins
  if nvim --headless -c "Lazy! sync" -c "qa!"; then
    print_success "Lazy plugins installed successfully"
  else
    print_error "Failed to install Lazy plugins"
    return 1
  fi

  # Install Mason tools
  print_status "Installing Mason tools..."
  if nvim --headless +"MasonInstall basedpyright css-lsp debugpy delve deno eslint-lsp goimports gomodifytags gopls gotests html-lsp iferr impl isort json-lsp js-debug-adapter prettierd vtsls vue-language-server" +qa; then
    print_success "Mason tools installed successfully"
  else
    print_error "Failed to install Mason tools"
    return 1
  fi
}

# Function to handle first-time setup
first_time_setup() {
  print_status "First-time setup detected. This may take a few minutes..."

  # Create necessary directories
  mkdir -p "$HOME/.config/nvim" \
    "$HOME/.local/share/nvim" \
    "$HOME/.local/state/nvim" \
    "$HOME/.cache/nvim" \
    "$HOME/.config/lazygit"

  # Install plugins
  if install_plugins; then
    print_success "Setup completed successfully!"
  else
    print_error "Setup failed. Neovim will start but some features may not work."
  fi
}

# Function to handle graceful shutdown
cleanup() {
  print_status "Shutting down..."
  exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main logic
main() {
  print_status "Starting Neovim container..."

  # Check if this is the first run (no plugins installed)
  if ! check_plugins; then
    # Only run setup if we're not just executing a command
    if { [ "$#" -eq 0 ] || [[ "$1" != -* ]]; } && [ -t 0 ]; then
      first_time_setup
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
  elif [ "$1" = "setup" ]; then
    # Force setup
    print_status "Force setup requested..."
    first_time_setup
    exit 0
  elif [ "$1" = "clean" ]; then
    # Clean plugins and cache
    print_status "Cleaning Neovim data..."
    rm -rf "$HOME/.local/share/nvim/lazy" \
      "$HOME/.local/state/nvim" \
      "$HOME/.cache/nvim"
    print_success "Cleanup completed"
    exit 0
  else
    # Pass all arguments to nvim
    print_status "Starting Neovim with arguments: $*"
    exec nvim "$@"
  fi
}

# Run main function with all arguments
main "$@"
