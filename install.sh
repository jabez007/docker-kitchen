#!/bin/bash
# install.sh - Modular Linux Development Environment Setup
# Usage: ./install.sh [OPTIONS] [COMPONENTS...]
# Components: base, go, node, editor, shell, docker
# Example: ./install.sh --debug base go editor

set -euo pipefail

# ============================================================================
# Configuration and Constants
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/setup.log"

# Component definitions
declare -A COMPONENTS=(
    [base]="install_base_dependencies"
    [go]="install_go"
    [node]="install_node_stack"
    [python]="install_python_stack"
    [editor]="install_editor_stack"
    [config]="install_user_configs"
    [shell]="install_shell_stack"
    [docker]="install_docker_stack"
)

declare -A COMPONENT_DESC=(
    [base]="Base dependencies (curl, git, build tools, etc.)"
    [go]="Go programming language and toolchain"
    [node]="Node.js stack (NVM, Node.js, Deno)"
    [python]="Python stack (pyenv and interpreters)"
    [editor]="Editor stack (Neovim, LazyGit, Bottom)"
    [config]="User configurations (Git, AstroNvim config)"
    [shell]="Shell stack (Fish, Tmux, Starship)"
    [docker]="Docker and Docker Compose stack"
)

readonly GITHUB_BRANCH="${GITHUB_BRANCH:-master}"
readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/jabez007/docker-kitchen/${GITHUB_BRANCH}"

# ============================================================================
# Module Loading Functions
# ============================================================================

download_missing_module() {
    local module_path="$1"
    local github_subdir="${2:-}"                        # Optional subdirectory parameter
    local relative_path="${module_path#"$SCRIPT_DIR"/}" # Strips off the $SCRIPT_DIR/ prefix from the absolute path to get the relative path within the repo

    # If a GitHub subdirectory is specified, prepend it to the relative path
    if [[ -n "$github_subdir" ]]; then
        local download_uri="${github_subdir}/${relative_path}"
    else
        local download_uri="${relative_path}"
    fi

    echo "Module not found locally: ${module_path}"
    echo "Attempting to download missing module: ${download_uri}"
    mkdir -p "$(dirname "$module_path")"

    local download_url="${GITHUB_BASE_URL}/${download_uri}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$download_url" -o "$module_path" || {
            echo "Error: Failed to download ${github_subdir:-$relative_path} from $download_url" >&2
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O "$module_path" || {
            echo "Error: Failed to download ${github_subdir:-$relative_path} from $download_url" >&2
            return 1
        }
    else
        echo "Error: Neither curl nor wget is available to download missing module: ${download_uri}" >&2
        echo "Check if the file exists at: ${module_path}" >&2
        return 1
    fi
}

safe_source() {
    local module_path="$1"
    local github_subdir="${2:-}" # Optional subdirectory parameter

    # If github_subdir is specified, the actual local path might be different
    local actual_local_path="$module_path"
    if [[ -n "$github_subdir" ]]; then
        local relative_path="${module_path#"$SCRIPT_DIR"/}"
        actual_local_path="${SCRIPT_DIR}/${github_subdir}/${relative_path}"
    fi

    echo "Sourcing module: ${actual_local_path} (requested: ${module_path})"

    if [[ ! -f "$actual_local_path" ]]; then
        # Check if the requested module_path itself exists (fallback for flattened structures like Docker)
        if [[ ! -f "$module_path" ]]; then
            download_missing_module "$module_path" "$github_subdir" || {
                echo "Critical Error: Failed to source module ${module_path}" >&2
                exit 1
            }
            # After download, the file should exist at module_path
            actual_local_path="$module_path"
        else
            echo "Using fallback path: ${module_path}"
            actual_local_path="$module_path"
        fi
    fi

    # shellcheck source=/dev/null
    if ! source "$actual_local_path"; then
        echo "Error: Failed to source ${actual_local_path}" >&2
        exit 1
    fi
}

echo "Running on branch '$GITHUB_BRANCH'"

# Load helper modules
safe_source "${SCRIPT_DIR}/.install/lib/config.sh"
safe_source "${SCRIPT_DIR}/.install/lib/utils.sh"
safe_source "${SCRIPT_DIR}/.install/lib/environment.sh"
safe_source "${SCRIPT_DIR}/.install/lib/package_manager.sh"
safe_source "${SCRIPT_DIR}/.install/lib/cli.sh"

# Load installation modules
safe_source "${SCRIPT_DIR}/.install/modules/base.sh"
safe_source "${SCRIPT_DIR}/.install/modules/go.sh" "astro-nvim"
safe_source "${SCRIPT_DIR}/.install/modules/node.sh" "astro-nvim"
safe_source "${SCRIPT_DIR}/.install/modules/python.sh" "astro-nvim"
safe_source "${SCRIPT_DIR}/.install/modules/editor.sh" "astro-nvim"
safe_source "${SCRIPT_DIR}/.install/modules/config.sh"
safe_source "${SCRIPT_DIR}/.install/modules/shell.sh"
safe_source "${SCRIPT_DIR}/.install/modules/docker.sh"

echo "DEBUG: All modules sourced successfully"

# ============================================================================
# Main Function
# ============================================================================

main() {
    echo "DEBUG: Entering main with arguments: $*"
    local components

    # Load configuration
    load_config

    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    info "Starting development environment setup"
    detect_environment
    info "System: $(detect_system), Package Manager: $(get_package_manager)"

    # Run directly in main shell to allow proper exiting
    local parsed
    if ! parsed="$(parse_arguments "$@")"; then
        echo "Error: parse_arguments failed" >&2
        exit 1
    fi
    echo "DEBUG: parse_arguments returned: $parsed"

    # Convert output into an array
    IFS=' ' read -r -a components <<<"$parsed"

    info "Components to install: ${components[*]}"

    # Process each component
    for component in "${components[@]}"; do
        if [[ -n "${COMPONENTS[$component]:-}" ]]; then
            info "Installing component: $component"
            ${COMPONENTS[$component]} || die "Failed to install component: $component"
        else
            warn "Unknown component: $component"
        fi
    done

    info "Setup completed successfully!"
    info "Log file: $LOG_FILE"

    # Show next steps
    cat <<EOF

=== Next Steps ===
1. Restart your terminal or run: source ~/.bashrc
2. If Docker was installed, you may need to log out and back in
3. For tmux plugins, run: tmux source ~/.tmux.conf and press prefix + I
4. Check the log file for any warnings: $LOG_FILE

EOF
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
