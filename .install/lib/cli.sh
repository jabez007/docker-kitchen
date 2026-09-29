#!/bin/bash
# lib/cli.sh - Command line interface functions

# Show usage information
show_usage() {
  local comp
  cat <<EOF
Usage: install.sh [OPTIONS] [COMPONENTS...]

A modular Linux development environment setup script.

COMPONENTS (always installed in this order):
$(for comp in "${COMPONENT_ORDER[@]}"; do printf "    %-8s - %s\n" "$comp" "${COMPONENT_DESC[$comp]:-No description available}"; done)
    all      - Install all components

OPTIONS:
    --debug, -d              Enable debug output
    --system-wide, -s        Install system-wide where applicable
    --upgrade, -u            Upgrade already installed components
    --keep-git               Keep .git directories in cloned configs
    --tmux-session NAME      Tmux session name (default: ${CONFIG["TMUX_SESSION"]})
    --starship-preset NAME   Starship preset (default: ${CONFIG["STARSHIP_PRESET"]})
    --astronvim-repo URL     AstroNvim config repository
    --git-name NAME          Git user.name, if not already set
    --git-email EMAIL        Git user.email, if not already set
    --config FILE            Read settings from FILE instead of setup.conf
    --save-config            Save the configuration (including other options given) and exit
    --help, -h               Show this help message

EXAMPLES:
    install.sh base go editor        # Install base tools, Go, and editor stack
    install.sh --debug all           # Install everything with debug output
    install.sh --system-wide base    # Install base dependencies system-wide
    install.sh editor config         # Install editor tools and user configs separately
    install.sh --git-name "Jane Doe" --save-config   # Save settings to setup.conf

CONFIG:
    Settings are read from: ${CONFIG_FILE:-nowhere (piped run; pass --config FILE)}

LOGS:
    Setup logs are written to: $LOG_FILE

NOTES:
    - 'editor' installs system-wide tools (Neovim, LazyGit, Bottom)
    - 'config' installs user-specific configurations (AstroNvim config)
    - When running as root or with sudo, configs are installed to the original user's home
EOF
}

# Parse command line arguments into CONFIG and SELECTED_COMPONENTS
parse_arguments() {
  debug "parse_arguments called with: $*"
  local -A selected=()
  local save=false comp

  while [[ $# -gt 0 ]]; do
    debug "Processing argument: $1"
    case "$1" in
    --debug | -d)
      CONFIG["LOG_LEVEL"]=DEBUG
      shift
      ;;
    --system-wide | -s)
      CONFIG["SYSTEM_WIDE"]=true
      shift
      ;;
    --upgrade | -u)
      CONFIG["UPGRADE"]=true
      shift
      ;;
    --keep-git)
      CONFIG["KEEP_GIT"]=true
      shift
      ;;
    --tmux-session)
      [[ $# -ge 2 ]] || die "--tmux-session requires a session name argument"
      CONFIG["TMUX_SESSION"]="$2"
      shift 2
      ;;
    --starship-preset)
      [[ $# -ge 2 ]] || die "--starship-preset requires a preset name argument"
      CONFIG["STARSHIP_PRESET"]="$2"
      shift 2
      ;;
    --astronvim-repo)
      [[ $# -ge 2 ]] || die "--astronvim-repo requires a git URL argument"
      CONFIG["ASTRONVIM_REPO"]="$2"
      shift 2
      ;;
    --git-name)
      [[ $# -ge 2 ]] || die "--git-name requires a name argument"
      CONFIG["GIT_USER_NAME"]="$2"
      shift 2
      ;;
    --git-email)
      [[ $# -ge 2 ]] || die "--git-email requires an email argument"
      CONFIG["GIT_USER_EMAIL"]="$2"
      shift 2
      ;;
    --config)
      # Already applied by set_config_file
      shift 2
      ;;
    --save-config)
      save=true
      shift
      ;;
    --help | -h)
      show_usage
      exit 0
      ;;
    all)
      for comp in "${COMPONENT_ORDER[@]}"; do selected[$comp]=1; done
      shift
      ;;
    *)
      [[ -v COMPONENTS["$1"] ]] || die "Unknown option or component: $1 (see --help)"
      selected[$1]=1
      shift
      ;;
    esac
  done

  if [[ "$save" == "true" ]]; then
    save_config
    exit 0
  fi

  # Dependencies run first (e.g. editor before config), so use the canonical order
  SELECTED_COMPONENTS=()
  for comp in "${COMPONENT_ORDER[@]}"; do
    if [[ -v selected[$comp] ]]; then
      SELECTED_COMPONENTS+=("$comp")
    fi
  done

  # If no components specified, show usage
  if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
    show_usage
    exit 1
  fi
}
