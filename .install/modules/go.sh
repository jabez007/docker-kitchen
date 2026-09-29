#!/bin/bash
# modules/go.sh - Go programming language installation

go_installed_version() {
  command_exists go && go version | awk '{print $3}'
}

go_latest_version() {
  curl -fsSL "https://go.dev/VERSION?m=text" | awk 'NR==1'
}

install_go() {
  should_install Go go_installed_version go_latest_version || return 0

  local go_ver go_url os arch tmp_dir

  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
  x86_64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  armv6l | armv7l) arch="armv6l" ;;
  i386 | i686) arch="386" ;;
  esac

  go_ver=$(go_latest_version) || die "Unable to resolve latest Go version"
  [[ -n "$go_ver" ]] || die "Unable to resolve latest Go version"
  go_url="https://go.dev/dl/${go_ver}.${os}-${arch}.tar.gz"

  debug "Go download URL: $go_url"

  tmp_dir=$(mktemp -d)
  curl -fL "$go_url" -o "${tmp_dir}/go.tar.gz" || die "Failed to download Go"
  run_as_admin rm -rf /usr/local/go
  run_as_admin tar -C /usr/local -xzf "${tmp_dir}/go.tar.gz" || die "Failed to extract Go"
  rm -rf "$tmp_dir"

  update_path "/usr/local/go/bin" "Go binaries"
  verify_installation go "Go"
}
