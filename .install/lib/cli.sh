#!/bin/bash
# lib/cli.sh - Command line interface functions

# Show usage information
show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [COMPONENTS...]

A modular Linux development environment setup script.

COMPONENTS:
    base     - Base dependencies (curl, git, build tools, etc.)
    go       - Go programming language
    node     - Node.js stack (NVM, Node.js, Deno)
    editor   - Editor stack (Neovim, LazyGit, Bottom, AstroNvim)
    config   - User configurations (AstroNvim, dotfiles)
    shell    - Shell stack (Fish, Tmux, Starship)
    docker   - Docker and Docker Compose
    all      - Install all components

OPTIONS:
    --debug, -d              Enable debug output
    --system-wide, -s        Install system-wide where applicable
    --keep-git               Keep .git directories in cloned configs
    --tmux-session NAME      Tmux session name (default: ${CONFIG[TMUX_SESSION]})
    --starship-preset NAME   Starship preset (default: ${CONFIG[STARSHIP_PRESET]})
    --astronvim-repo URL     AstroNvim config repository
    --save-config            Save current configuration
    --help, -h               Show this help message

EXAMPLES:
    $0 base go editor        # Install base tools, Go, and editor stack
    $0 --debug all           # Install everything with debug output
    $0 --system-wide base    # Install base dependencies system-wide
    $0 editor config         # Install editor tools and user configs separately
    $0 --save-config         # Save current configuration

LOGS:
    Setup logs are written to: $LOG_FILE

NOTES:
    - 'editor' installs system-wide tools (Neovim, LazyGit, Bottom)
    - 'config' installs user-specific configurations (AstroNvim config)
    - When running as root or with sudo, configs are installed to the original user's home
EOF
}

# Parse command line arguments
parse_arguments() {
  local components=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --debug | -d)
      CONFIG[LOG_LEVEL]=DEBUG
      shift
      ;;
    --system-wide | -s)
      CONFIG[SYSTEM_WIDE]=true
      shift
      ;;
    --keep-git)
      CONFIG[KEEP_GIT]=true
      shift
      ;;
    --tmux-session)
      [[ $# -ge 2 ]] || die "--tmux-session requires a session name argument"
      CONFIG[TMUX_SESSION]="$2"
      shift 2
      ;;
    --starship-preset)
      [[ $# -ge 2 ]] || die "--starship-preset requires a preset name argument"
      CONFIG[STARSHIP_PRESET]="$2"
      shift 2
      ;;
    --astronvim-repo)
      [[ $# -ge 2 ]] || die "--astronvim-repo requires a git URL argument"
      CONFIG[ASTRONVIM_REPO]="$2"
      shift 2
      ;;
    --save-config)
      save_config
      exit 0
      ;;
    --help | -h)
      show_usage
      exit 0
      ;;
    base | go | node | editor | config | shell | docker)
      components+=("$1")
      shift
      ;;
    all)
      components=(base go node editor config shell docker)
      shift
      ;;
    *)
      die "Unknown option: $1\nUse --help for usage information."
      ;;
    esac
  done

  # If no components specified, show usage
  if [[ ${#components[@]} -eq 0 ]]; then
    show_usage
    exit 1
  fi

  # Return the components list
  echo "${components[@]}"
}
