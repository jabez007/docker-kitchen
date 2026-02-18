#!/bin/bash
# lib/config.sh - Configuration management

readonly CONFIG_FILE="${SCRIPT_DIR}/setup.conf"

# Default configuration
declare -g -A CONFIG=(
  [SYSTEM_WIDE]=false
  [KEEP_GIT]=true
  [TMUX_SESSION]="default"
  [STARSHIP_PRESET]="gruvbox-rainbow"
  [ASTRONVIM_REPO]="https://github.com/jabez007/AstroNvim-config.git"
  [LOG_LEVEL]="INFO"
  [UPGRADE]=false
)

# Load configuration from file
load_config() {
  echo "DEBUG: Checking for config file at $CONFIG_FILE"
  if [[ -f "$CONFIG_FILE" ]]; then
    debug "Loading configuration from $CONFIG_FILE"
    echo "DEBUG: Loading configuration from $CONFIG_FILE"
    # shellcheck source=./setup.conf
    source "$CONFIG_FILE"

    # sync scalar vars -> associative array
    for k in SYSTEM_WIDE KEEP_GIT TMUX_SESSION \
      STARSHIP_PRESET ASTRONVIM_REPO LOG_LEVEL UPGRADE; do
      if [[ -v $k ]]; then
        echo "DEBUG: Syncing $k=${!k} to CONFIG[$k]"
        CONFIG[$k]="${!k}"
      fi
    done
  fi
}

# Save configuration to file
save_config() {
  info "Saving configuration to $CONFIG_FILE"
  cat >"$CONFIG_FILE" <<EOF
# Development Environment Setup Configuration
# Generated on $(date)

SYSTEM_WIDE=${CONFIG[SYSTEM_WIDE]}
UPGRADE=${CONFIG[UPGRADE]}
KEEP_GIT=${CONFIG[KEEP_GIT]}
TMUX_SESSION="${CONFIG[TMUX_SESSION]}"
STARSHIP_PRESET="${CONFIG[STARSHIP_PRESET]}"
ASTRONVIM_REPO="${CONFIG[ASTRONVIM_REPO]}"
LOG_LEVEL="${CONFIG[LOG_LEVEL]}"
EOF
}
