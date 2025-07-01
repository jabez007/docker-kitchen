#!/bin/bash

set -euo pipefail

# Global variables
ASTRONVIM_REPO="https://github.com/jabez007/AstroNvim-config.git"
debug=false
keep_git=false

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
  --debug | -d)
    debug=true
    shift
    ;;
  --keep-git)
    keep_git=true
    shift
    ;;
  *)
    printf "Unknown option: %s\n" "$1" >&2
    exit 1
    ;;
  esac
done

# Enable debugging if --debug or -d is passed
if $debug; then
  set -x
fi

# Function to install Deno
install_deno() {
  if command -v deno >/dev/null 2>&1; then
    printf "Deno is already installed. Skipping installation.\n"
    return 0
  fi

  printf "Installing Deno...\n"

  if ! curl -SL https://deno.land/install.sh | sh -s -- -y; then
    printf "Error: Deno installation failed.\n" >&2
    return 1
  fi

  printf "Deno installed successfully.\n"
}

# Function to install NVM
install_nvm() {
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    printf "NVM is already installed. Skipping installation.\n"
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    return 0
  fi

  local nvm_version

  printf "Fetching latest version of NVM.\n"

  nvm_version=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest |
    grep '"tag_name"' | cut -d '"' -f 4)

  if [[ -z "$nvm_version" ]]; then
    printf "Error: Unable to fetch the latest NVM version.\n" >&2
    return 1
  fi

  printf "Installing NVM version %s...\n" "$nvm_version"

  if ! curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash; then
    printf "Error: NVM installation failed.\n" >&2
    return 1
  fi

  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}

# Function to install the latest LTS version of Node.js
install_node_lts() {
  printf "Installing the latest LTS version of Node.js...\n"

  if ! nvm install --lts; then
    printf "Error: Node.js LTS installation failed.\n" >&2
    return 1
  fi

  printf "Latest LTS version of Node.js installed successfully.\n"
}

# Function to configure Fish shell for NVM
configure_fish_for_nvm() {
  if command -v fish >/dev/null 2>&1; then
    printf "Fish shell detected. Configuring NVM for Fish shell...\n"

    # Install Fisher (Fish plugin manager)
    if ! curl -sL https://git.io/fisher --create-dirs -o "$HOME/.config/fish/functions/fisher.fish"; then
      printf "Error: Fisher installation failed.\n" >&2
      return 1
    fi

    # Install Bass plugin
    if ! fish -c 'fisher install edc/bass'; then
      printf "Error: Bass plugin installation failed.\n" >&2
      return 1
    fi

    # File path for NVM function in Fish shell
    local nvm_fish_file="$HOME/.config/fish/functions/nvm.fish"

    # Check if the file already exists
    if [[ -f "$nvm_fish_file" ]]; then
      printf "The file %s already exists. Skipping creation.\n" "$nvm_fish_file"
    else
      # Create nvm.fish if it doesn't exist
      printf "Creating NVM integration for Fish shell...\n"
      mkdir -p "$(dirname "$nvm_fish_file")"
      cat <<'EOF' >"$nvm_fish_file"
function nvm
    bass source ~/.nvm/nvm.sh --no-use ';' nvm $argv
end
EOF
      printf "NVM configured for Fish shell successfully.\n"
    fi
  else
    printf "Fish shell not detected; skipping NVM configuration for Fish.\n"
  fi
}

# Function to clone AstroNvim configuration
clone_astronvim_config() {
  printf "Cloning AstroNvim config...\n"

  local config_dir="$HOME/.config/nvim"

  if [ -d "${config_dir}" ]; then
    printf "Warning: '%s' already exists. Skipping clone.\n" "${config_dir}"
  else
    if ! git clone --depth 1 "${ASTRONVIM_REPO}" "${config_dir}"; then
      printf "Error: Cloning AstroNvim configuration failed.\n" >&2
      return 1
    fi
    if [ "$keep_git" = false ]; then
      rm -rf "${config_dir}/.git"
    fi
    printf "AstroNvim config cloned successfully.\n"
  fi
}

# Main function to orchestrate installations
main() {
  install_deno || {
    printf "Failed to install Deno.\n" >&2
    exit 1
  }
  install_nvm || {
    printf "Failed to install NVM.\n" >&2
    exit 1
  }
  install_node_lts || {
    printf "Failed to install Node.js.\n" >&2
    exit 1
  }
  configure_fish_for_nvm || {
    printf "Failed to configure Fish shell.\n" >&2
    exit 1
  }
  clone_astronvim_config || {
    printf "Failed to clone AstroNvim config.\n" >&2
    exit 1
  }

  printf "All utilities set up successfully.\n"
}

# Execute main function
main "$@"
