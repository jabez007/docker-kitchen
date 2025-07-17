#!/bin/bash
# modules/go.sh - Go programming language installation

install_go() {
  if command_exists go; then
    info "Go is already installed, skipping..."
    return 0
  fi

  info "Installing Go..."
  local go_ver go_url arch

  arch=$(uname -m)
  case "$arch" in
  x86_64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  armv6l) arch="armv6l" ;;
  armv7l) arch="armv6l" ;;
  i386) arch="386" ;;
  esac

  go_ver=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n1) ||
    die "Unable to resolve latest Go version"
  [[ -n "$go_ver" ]] || die "Unable to resolve latest Go version"
  go_url="https://go.dev/dl/${go_ver}.linux-${arch}.tar.gz"

  debug "Go download URL: $go_url"

  curl -L "$go_url" -o /tmp/go.tar.gz || die "Failed to download Go"
  run_as_admin rm -rf /usr/local/go
  run_as_admin tar -C /usr/local -xzf /tmp/go.tar.gz || die "Failed to extract Go"
  rm /tmp/go.tar.gz

  update_path "/usr/local/go/bin" "Go binaries"
  verify_installation go "Go"
}
