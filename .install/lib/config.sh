#!/bin/bash
# lib/config.sh - Configuration management

# setup.conf is sourced as shell code. A piped run (curl ... | bash) doesn't
# look for one in the cwd, which may not be trusted; it needs --config.
if [[ "$PIPED" == "true" ]]; then
  CONFIG_FILE=""
else
  CONFIG_FILE="${STATE_DIR}/setup.conf"
fi

# Settings that setup.conf may set and --save-config writes
readonly CONFIG_KEYS=(
  SYSTEM_WIDE UPGRADE KEEP_GIT TMUX_SESSION STARSHIP_PRESET
  ASTRONVIM_REPO GIT_USER_NAME GIT_USER_EMAIL NERD_FONT LOG_LEVEL
)

# Default configuration
declare -g -A CONFIG=(
  [SYSTEM_WIDE]=false
  [KEEP_GIT]=true
  [TMUX_SESSION]="default"
  [STARSHIP_PRESET]="gruvbox-rainbow"
  [ASTRONVIM_REPO]="https://github.com/jabez007/AstroNvim-config.git"
  [GIT_USER_NAME]=""
  [GIT_USER_EMAIL]=""
  [NERD_FONT]="Mononoki"
  [LOG_LEVEL]="INFO"
  [UPGRADE]=false
)

# Pick up --config FILE. load_config runs before parse_arguments, so this scans
# the arguments on its own; parse_arguments then skips --config.
set_config_file() {
  local file="" saving=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --config)
      [[ $# -ge 2 ]] || die "--config requires a file argument"
      file="$2"
      shift 2
      ;;
    --save-config)
      saving=true
      shift
      ;;
    *) shift ;;
    esac
  done

  if [[ -n "$file" ]]; then
    # --save-config may create the file; anything else needs it to exist
    [[ -f "$file" || "$saving" == "true" ]] || die "Config file not found: $file"
    CONFIG_FILE="$file"
  fi
  readonly CONFIG_FILE
}

# Load configuration from file
load_config() {
  if [[ -z "$CONFIG_FILE" ]]; then
    debug "Piped run without --config; using defaults"
    return 0
  fi

  debug "Checking for config file at $CONFIG_FILE"
  if [[ -f "$CONFIG_FILE" ]]; then
    debug "Loading configuration from $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    # sync scalar vars -> associative array
    local k
    for k in "${CONFIG_KEYS[@]}"; do
      if [[ -v $k ]]; then
        debug "Syncing $k=${!k} to CONFIG[$k]"
        CONFIG[$k]="${!k}"
      fi
    done
  fi
}

# Save configuration to file
save_config() {
  [[ -n "$CONFIG_FILE" ]] || die "A piped run needs --config FILE to know where to save"
  info "Saving configuration to $CONFIG_FILE"
  {
    echo "# Development Environment Setup Configuration"
    echo "# Generated on $(date)"
    echo
    local k
    for k in "${CONFIG_KEYS[@]}"; do
      printf '%s=%q\n' "$k" "${CONFIG[$k]}"
    done
  } >"$CONFIG_FILE"
}
