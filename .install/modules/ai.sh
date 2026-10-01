#!/bin/bash
# modules/ai.sh - AI coding agents (Claude Code, Codex, OpenCode, Pi) and Herdr

# The tools AI_TOOLS may name, in install order
readonly AI_TOOL_NAMES=(claude codex opencode pi herdr)

readonly CLAUDE_RELEASES="https://downloads.claude.ai/claude-code-releases"

install_ai_stack() {
  local tools=() tool node
  # AI_TOOLS is a comma-separated list; accept spaces too
  read -ra tools <<<"${CONFIG[AI_TOOLS]//,/ }"
  [[ ${#tools[@]} -gt 0 ]] || die "AI_TOOLS is empty; name at least one of: ${AI_TOOL_NAMES[*]}"
  for tool in "${tools[@]}"; do
    [[ " ${AI_TOOL_NAMES[*]} " == *" $tool "* ]] ||
      die "Unknown AI tool: $tool (pick from: ${AI_TOOL_NAMES[*]})"
  done

  info "Installing AI tools (${tools[*]})..."
  node=$(node_installed_version 2>/dev/null || true)

  for tool in "${tools[@]}"; do
    case "$tool" in
    claude)
      if should_install "Claude Code" claude_installed_version claude_latest_version; then
        install_claude_code
      fi
      ;;
    codex) install_npm_agent Codex @openai/codex "$node" ;;
    # Its postinstall links the binary for this CPU into place. npm 11.19
    # started warning about install scripts nobody approved, so approve it.
    opencode) install_npm_agent OpenCode opencode-ai "$node" --allow-scripts=opencode-ai ;;
    # Pi's own install docs skip lifecycle scripts, and it needs none
    pi) install_npm_agent Pi @earendil-works/pi-coding-agent "$node" --ignore-scripts ;;
    herdr)
      if should_install Herdr herdr_installed_version github_latest_version herdrdev/herdr; then
        install_herdr
      fi
      ;;
    esac
  done

  # Claude Code always goes in ~/.local/bin, and Herdr does without --system-wide
  if [[ " ${tools[*]} " == *" claude "* ]] ||
    [[ " ${tools[*]} " == *" herdr "* && "${CONFIG[SYSTEM_WIDE]}" != "true" ]]; then
    update_path "$(get_user_home)/.local/bin" "User binaries (Claude Code, Herdr)"
  fi

  # A node component from before this one didn't put npm's commands on Fish's PATH
  if [[ -n "$node" ]] && command_exists fish; then
    configure_fish_node_path
  fi
}

# ============================================================================
# Claude Code
# ============================================================================

claude_installed_version() {
  local bin
  bin="$(get_user_home)/.local/bin/claude"
  [[ -x "$bin" ]] || return 0
  run_as_user "$bin" --version | awk 'NR==1 {print $1}'
}

claude_latest_version() {
  local version
  version=$(curl -fsSL "${CLAUDE_RELEASES}/latest") || return 1
  # Anything else is an error page, e.g. in a region Anthropic doesn't serve
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || return 1
  echo "$version"
}

# Download the native binary and check it against the SHA-256 in the
# release's manifest.json, as Anthropic's install.sh does. Then the binary's
# own `install` puts the launcher in ~/.local/bin and the release under
# ~/.local/share/claude, where Claude Code updates itself in the background.
# The user runs it, since Claude Code is a per-user install.
install_claude_code() {
  local os arch platform version manifest sum tmp_dir

  case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) die "Unsupported OS for Claude Code: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
  x86_64 | amd64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) die "Unsupported architecture for Claude Code: $(uname -m)" ;;
  esac
  platform="${os}-${arch}"
  if [[ "$os" == linux ]] &&
    { [[ -f /lib/libc.musl-x86_64.so.1 || -f /lib/libc.musl-aarch64.so.1 ]] || ldd /bin/ls 2>&1 | grep -q musl; }; then
    platform+="-musl"
  fi

  version=$(claude_latest_version) || die "Could not resolve the latest Claude Code release"
  manifest=$(curl -fsSL "${CLAUDE_RELEASES}/${version}/manifest.json") ||
    die "Failed to download the Claude Code manifest"
  # "<platform>": {..., "checksum": "<sha256>", ...}, read without jq. [^{}]
  # keeps the match inside that platform's own object.
  if [[ "$(tr -d ' \n\r\t' <<<"$manifest")" =~ \"${platform}\":\{[^{}]*\"checksum\":\"([0-9a-f]{64})\" ]]; then
    sum="${BASH_REMATCH[1]}"
  else
    die "Claude Code $version has no build for $platform"
  fi

  tmp_dir=$(run_as_user mktemp -d)
  run_as_user curl -fL "${CLAUDE_RELEASES}/${version}/${platform}/claude" -o "${tmp_dir}/claude" ||
    die "Failed to download Claude Code"
  verify_sha256 "${tmp_dir}/claude" "$sum"
  run_as_user chmod 0755 "${tmp_dir}/claude"
  run_as_user "${tmp_dir}/claude" install "$version" || die "Claude Code installation failed"
  rm -rf "$tmp_dir"
}

# ============================================================================
# Agents from npm (Codex, OpenCode, Pi)
# ============================================================================

# Version of npm_package (set by install_npm_agent, since should_install
# passes no arguments) in the default Node's global node_modules, which nvm
# keeps next to NVM_BIN; nothing if it isn't there
npm_global_version() {
  nvm_run "node -p 'require(process.argv[1]).version' \"\$NVM_BIN/../lib/node_modules/${npm_package}/package.json\""
}

npm_latest_version() {
  nvm_run "npm view '$1' version"
}

# Install an agent into the default Node from nvm, so `install.sh --upgrade
# node` carries it to the next LTS with the other global packages.
# --engine-strict makes npm refuse a release that needs a newer Node, instead
# of warning and installing it anyway.
#   install_npm_agent <name> <package> <node-version> [npm flags...]
install_npm_agent() {
  local name="$1" npm_package="$2" node="$3"
  shift 3

  if [[ -z "$node" ]]; then
    warn "Skipping $name: it installs with npm, and there's no Node.js from NVM. Run install.sh node ai."
    return 0
  fi
  should_install "$name" npm_global_version npm_latest_version "$npm_package" || return 0

  # Quote each flag for nvm_run's bash -c. Not with no flags, where printf
  # would still print '' and hand npm an empty argument.
  local flags=""
  if [[ $# -gt 0 ]]; then
    flags=$(printf '%q ' "$@")
  fi
  nvm_run "npm install -g --engine-strict ${flags}'${npm_package}@latest'" ||
    die "Failed to install $name. If npm reported EBADENGINE, run install.sh --upgrade node first."
}

# ============================================================================
# Herdr
# ============================================================================

# ~/.local/bin, so `herdr update` can replace itself, or /usr/local/bin with
# --system-wide
herdr_dir() {
  if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
    echo /usr/local/bin
  else
    echo "$(get_user_home)/.local/bin"
  fi
}

herdr_installed_version() {
  local bin
  bin="$(herdr_dir)/herdr"
  [[ -x "$bin" ]] || return 0
  "$bin" --version | awk 'NR==1 {print $2}'
}

# Herdr publishes bare binaries and no checksum file, so this checks the
# digest GitHub computed when each was uploaded
install_herdr() {
  local asset tag url tmp_dir dir

  case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) asset=herdr-linux-x86_64 ;;
  Linux-aarch64 | Linux-arm64) asset=herdr-linux-aarch64 ;;
  Darwin-x86_64) asset=herdr-macos-x86_64 ;;
  Darwin-arm64) asset=herdr-macos-aarch64 ;;
  *) die "Unsupported platform for Herdr: $(uname -s) $(uname -m)" ;;
  esac

  tag=$(github_latest_version herdrdev/herdr) || die "Could not resolve the latest Herdr release"
  url="https://github.com/herdrdev/herdr/releases/download/${tag}/${asset}"
  debug "Herdr download URL: $url"

  tmp_dir=$(run_as_user mktemp -d)
  run_as_user curl -fL "$url" -o "${tmp_dir}/herdr" || die "Failed to download Herdr"
  verify_sha256 "${tmp_dir}/herdr" "$(github_asset_sha256 "$url")"

  dir=$(herdr_dir)
  if [[ "${CONFIG[SYSTEM_WIDE]}" == "true" ]]; then
    run_as_admin install -m 0755 "${tmp_dir}/herdr" "${dir}/herdr"
  else
    run_as_user mkdir -p "$dir"
    run_as_user install -m 0755 "${tmp_dir}/herdr" "${dir}/herdr"
  fi
  rm -rf "$tmp_dir"
}
