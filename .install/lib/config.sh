#!/bin/bash
# lib/config.sh - Configuration management

# Load configuration from file
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    debug "Loading configuration from $CONFIG_FILE"
    # shellcheck source=./setup.conf
    source "$CONFIG_FILE"

    # sync scalar vars -> associative array
    for k in SYSTEM_WIDE KEEP_GIT TMUX_SESSION \
      STARSHIP_PRESET ASTRONVIM_REPO LOG_LEVEL; do
      [[ -v $k ]] && CONFIG[$k]="${!k}"
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
KEEP_GIT=${CONFIG[KEEP_GIT]}
TMUX_SESSION="${CONFIG[TMUX_SESSION]}"
STARSHIP_PRESET="${CONFIG[STARSHIP_PRESET]}"
ASTRONVIM_REPO="${CONFIG[ASTRONVIM_REPO]}"
LOG_LEVEL="${CONFIG[LOG_LEVEL]}"
EOF
}
