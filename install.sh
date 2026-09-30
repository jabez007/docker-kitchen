#!/bin/bash
# install.sh - Modular Linux Development Environment Setup
# Usage: ./install.sh [OPTIONS] [COMPONENTS...]
# Components: base, shell, go, node, python, editor, docker, config, font
# Example: ./install.sh --debug base go editor

set -Eeuo pipefail

# ============================================================================
# Configuration and Constants
# ============================================================================

# BASH_SOURCE is unset when the script is piped into bash (curl ... | bash).
# Then modules are downloaded into a temp dir, setup.log goes in the cwd, and
# only a config passed with --config is read.
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    STATE_DIR="$SCRIPT_DIR"
    PIPED=false
else
    SCRIPT_DIR="$(mktemp -d)"
    STATE_DIR="$PWD"
    PIPED=true
    trap 'rm -rf "$SCRIPT_DIR"' EXIT
fi
# shellcheck disable=SC2034 # PIPED is used by lib/config.sh
readonly SCRIPT_DIR STATE_DIR PIPED
readonly LOG_FILE="${STATE_DIR}/setup.log"

# Install order: `all`, and any set of components given on the command line, run in this order
readonly COMPONENT_ORDER=(base shell go node python editor docker config font)

declare -A COMPONENTS=(
    [base]="install_base_dependencies"
    [go]="install_go"
    [node]="install_node_stack"
    [python]="install_python_stack"
    [editor]="install_editor_stack"
    [config]="install_user_configs"
    [shell]="install_shell_stack"
    [docker]="install_docker_stack"
    [font]="install_nerd_font"
)

# shellcheck disable=SC2034 # used by lib/cli.sh
declare -A COMPONENT_DESC=(
    [base]="Base dependencies (curl, git, build tools, etc.)"
    [go]="Go programming language and toolchain"
    [node]="Node.js stack (NVM, Node.js, Deno)"
    [python]="Python stack (pyenv and build dependencies)"
    [editor]="Editor stack (Neovim, LazyGit, Bottom)"
    [config]="User configurations (Git, AstroNvim config)"
    [shell]="Shell stack (Fish, Tmux, Starship, Atuin)"
    [docker]="Docker and Docker Compose stack"
    [font]="Nerd Font for the terminal (not part of all)"
)

readonly GITHUB_BRANCH="${GITHUB_BRANCH:-master}"
readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/jabez007/docker-kitchen/${GITHUB_BRANCH}"

# ============================================================================
# Module Loading
# ============================================================================

# Source .install/<path>, downloading it from GitHub first if it is missing
# (e.g. when install.sh was fetched on its own)
load_module() {
    local rel_path=".install/$1"
    local module_path="${SCRIPT_DIR}/${rel_path}"
    local url="${GITHUB_BASE_URL}/${rel_path}"

    if [[ ! -f "$module_path" ]]; then
        if [[ "${LOG_LEVEL:-}" == "DEBUG" ]]; then
            echo "DEBUG: Downloading missing module: ${url}" >&2
        fi
        mkdir -p "$(dirname "$module_path")"

        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$url" -o "$module_path"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$url" -O "$module_path"
        else
            echo "Error: curl or wget is needed to download ${rel_path}" >&2
            exit 1
        fi || {
            rm -f "$module_path"
            echo "Error: Failed to download ${url}" >&2
            exit 1
        }
    fi

    # shellcheck source=/dev/null
    source "$module_path"
}

[[ "${LOG_LEVEL:-}" == "DEBUG" ]] && echo "DEBUG: Running on branch '$GITHUB_BRANCH'" >&2

for lib in utils config environment package_manager cli; do
    load_module "lib/${lib}.sh"
done
for component in "${COMPONENT_ORDER[@]}"; do
    load_module "modules/${component}.sh"
done
unset lib component

debug "All modules sourced successfully"

# ============================================================================
# Main Function
# ============================================================================

main() {
    set_config_file "$@"
    load_config
    parse_arguments "$@"
    debug "Selected components: ${SELECTED_COMPONENTS[*]}"

    info "Starting development environment setup"
    detect_environment
    info "System: $(detect_system), Package Manager: $(get_package_manager)"

    # Any failing command aborts the run (set -e); report where it happened
    CURRENT_COMPONENT=""
    trap 'error "Command failed (exit $?) at ${BASH_SOURCE[0]:-install.sh}:${LINENO} while installing: ${CURRENT_COMPONENT:-?}"' ERR

    for CURRENT_COMPONENT in "${SELECTED_COMPONENTS[@]}"; do
        info "Installing component: $CURRENT_COMPONENT"
        "${COMPONENTS[$CURRENT_COMPONENT]}"
    done
    CURRENT_COMPONENT="final .bashrc cleanup"
    move_fish_launcher_last

    info "Setup completed successfully!"
    info "Log file: $LOG_FILE"

    cat <<EOF

=== Next Steps ===
1. Restart your terminal or run: source ~/.bashrc
2. If Docker was installed, you may need to log out and back in
3. For tmux plugins, run: tmux source ~/.tmux.conf and press prefix + I
4. Check the log file for any warnings: $LOG_FILE

EOF
}

# Run main unless this file is being sourced (BASH_SOURCE is unset when piped into bash)
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
