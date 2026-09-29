#!/bin/bash
# lib/utils.sh - Utility functions

# ============================================================================
# Logging Functions
# ============================================================================

# Logging functions
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Skip messages below the configured level (unknown levels count as INFO)
  local -A prio=([ERROR]=0 [WARN]=1 [INFO]=2 [DEBUG]=3)
  local current="${CONFIG["LOG_LEVEL"]:-INFO}"
  if ((${prio[$level]:-2} > ${prio[${current^^}]:-2})); then
    return 0
  fi

  case "$level" in
  ERROR) echo -e "\033[31m[ERROR]\033[0m $message" >&2 ;;
  WARN) echo -e "\033[33m[WARN]\033[0m $message" ;;
  INFO) echo -e "\033[32m[INFO]\033[0m $message" ;;
  DEBUG) echo -e "\033[36m[DEBUG]\033[0m $message" ;;
  esac

  # Also log to file; an unwritable log (e.g. read-only mount) is not an error
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "[$timestamp] [$level] $message" 2>/dev/null >>"$LOG_FILE" || true
  fi
}

error() { log ERROR "$@"; }
warn() { log WARN "$@"; }
info() { log INFO "$@"; }
debug() { log DEBUG "$@"; }

# Exit with error
die() {
  error "$@"
  exit 1
}

# ============================================================================
# System Utilities
# ============================================================================

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Trim whitespace
trim() {
  echo "$1" | awk '{$1=$1};1'
}

# Detect OS and architecture
detect_system() {
  local os arch

  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    os="$ID"
  elif command_exists lsb_release; then
    os=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
  elif [[ -f /etc/redhat-release ]]; then
    os="rhel"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    os="macos"
  else
    os="unknown"
  fi

  arch=$(uname -m)
  case "$arch" in
  x86_64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  armv7l) arch="armv7" ;;
  esac

  echo "$os:$arch"
}

# ============================================================================
# Path Management
# ============================================================================

# Update PATH and persist it
update_path() {
  local path_entry="$1"
  local comment="${2:-Add to PATH}"
  local shell_configs=()
  local run_command

  # Update current session
  export PATH="$PATH:$path_entry"

  # Determine config file
  if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
    # System-wide: Update both profile and bashrc for maximum compatibility
    shell_configs=("/etc/profile" "/etc/bash.bashrc")

    # Add zsh system config if zsh is installed
    if command_exists zsh && [[ -f "/etc/zsh/zshrc" ]]; then
      shell_configs+=("/etc/zsh/zshrc")
    fi

    run_command="run_as_admin"
  else
    # User-specific: Prefer .profile for PATH (shell-agnostic), but also update shell-specific configs
    local user_home
    user_home=$(get_user_home)

    # Start with .profile (shell-agnostic)
    shell_configs=("${user_home}/.profile")

    # Add shell-specific configs for interactive shells
    if [[ -n "${ZSH_VERSION-}" ]] || command_exists zsh; then
      shell_configs+=("${user_home}/.zshrc")
    fi

    # Add .bashrc for interactive bash sessions
    shell_configs+=("${user_home}/.bashrc")

    run_command="run_as_user"
  fi

  # Update each config file
  for shell_config in "${shell_configs[@]}"; do
    # Create directory if it doesn't exist (for user configs)
    if [[ "${CONFIG[SYSTEM_WIDE]}" != "true" ]]; then
      $run_command mkdir -p "$(dirname "$shell_config")"
    fi

    # Add to config if not present
    if ! grep -qxF "export PATH=\"\$PATH:${path_entry}\"" "$shell_config" 2>/dev/null; then
      {
        echo ""
        echo "# $comment"
        echo "export PATH=\"\$PATH:${path_entry}\""
      } | $run_command tee -a "$shell_config" >/dev/null
      info "Updated PATH in $shell_config"
    fi
  done

  # Fish shell specific PATH update
  if command_exists fish; then
    local escaped_path
    escaped_path=$(printf '%q' "$path_entry")
    if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
      run_as_admin fish -c "fish_add_path -m $escaped_path" 2>/dev/null || true
    else
      run_as_user fish -c "fish_add_path -m $escaped_path" 2>/dev/null || true
    fi
    info "Updated PATH for Fish shell"
  fi
}

# ============================================================================
# Versions and Upgrades
# ============================================================================

# Latest release tag of a GitHub repo (owner/name), e.g. v0.12.5. Follows the
# releases/latest redirect, so it needs neither jq nor an API token.
github_latest_version() {
  local url
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") || return 1
  [[ "$url" == */releases/tag/* ]] || return 1
  echo "${url##*/}"
}

# Download URL of the first asset in a repo's latest release whose path matches
# an extended regex (case-insensitive), e.g. '/tool_[^/]*_linux_x86_64\.tar\.gz$'.
# It reads the asset list the release page loads rather than the REST API,
# whose 60 requests/hour limit for anonymous clients CI runners hit.
#   github_release_asset_url <owner/name> <regex>
github_release_asset_url() {
  local repo="$1" pattern="$2" tag assets path
  tag=$(github_latest_version "$repo") || return 1
  assets=$(curl -fsSL "https://github.com/$repo/releases/expanded_assets/$tag" |
    grep -o 'href="[^"]*/releases/download/[^"]*"' | sed 's/^href="//; s/"$//') || return 1
  # sed -n 1p reads all its input, so nothing upstream dies of SIGPIPE under pipefail
  path=$(grep -iE "$pattern" <<<"$assets" | sed -n 1p) || return 1
  [[ -n "$path" ]] || return 1
  echo "https://github.com${path}"
}

# SHA-256 digest GitHub lists for a release asset, from its download URL
# (https://github.com/<owner>/<repo>/releases/download/<tag>/<file>). GitHub
# computes it when the asset is uploaded. It catches a corrupted, truncated or
# altered download, but not an asset someone replaced on GitHub itself.
#   github_asset_sha256 <download-url>
github_asset_sha256() {
  local path repo tag name
  path="${1#https://github.com/}"
  repo="${path%%/releases/download/*}"
  tag="${path#*/releases/download/}"
  name="${tag#*/}"
  tag="${tag%%/*}"
  # The asset list has one copy-to-clipboard button per asset, labelled
  # "digest for <file>" with the digest on the same line
  curl -fsSL "https://github.com/$repo/releases/expanded_assets/$tag" |
    grep -F "digest for ${name}\"" | grep -oE 'sha256:[0-9a-f]{64}' | sed -n '1s/^sha256://p'
}

# Stop the run unless a downloaded file's SHA-256 matches the one upstream
# publishes. An empty or malformed expected value also stops it, so a checksum
# that failed to parse can't pass silently.
#   verify_sha256 <file> <expected-hex>
verify_sha256() {
  local file="$1" expected="${2:-}" actual
  expected="${expected,,}"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] ||
    die "No valid SHA-256 to check ${file##*/} against (got '${2:-}')"

  if command_exists sha256sum; then
    actual=$(sha256sum "$file")
  else
    actual=$(shasum -a 256 "$file")
  fi
  actual="${actual%% *}"

  [[ "$actual" == "$expected" ]] ||
    die "Checksum mismatch for ${file##*/}: expected $expected, got $actual"
  debug "SHA-256 OK for ${file##*/}"
}

# Decide whether to install a tool: yes if it's missing, or if --upgrade is set
# and the installed version isn't the latest.
#   should_install <name> <installed-version-fn> <latest-version-fn> [latest-fn args...]
# installed-version-fn prints nothing when the tool is missing. Versions are
# compared with any leading "v" removed.
should_install() {
  local name="$1" installed_fn="$2" latest_fn="$3"
  shift 3
  local installed latest

  installed=$("$installed_fn" 2>/dev/null || true)
  if [[ -z "$installed" ]]; then
    info "Installing $name..."
    return 0
  fi

  if [[ "${CONFIG[UPGRADE]}" != "true" ]]; then
    info "$name $installed already installed"
    return 1
  fi

  latest=$("$latest_fn" "$@" 2>/dev/null || true)
  if [[ -z "$latest" ]]; then
    warn "Couldn't look up the latest $name version; reinstalling"
    return 0
  fi
  if [[ "${installed#v}" == "${latest#v}" ]]; then
    info "$name $installed is up to date"
    return 1
  fi

  info "Upgrading $name from $installed to $latest..."
  return 0
}

# ============================================================================
# Installation Verification
# ============================================================================

# Verify installation
verify_installation() {
  local command="$1"
  local name="${2:-$command}"

  if command_exists "$command"; then
    info "$name installed successfully"
    return 0
  else
    error "$name installation failed - command not found"
    return 1
  fi
}
