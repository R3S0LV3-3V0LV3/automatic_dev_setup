#!/usr/bin/env bash
# =============================================================================
# 05-development-stack.sh - Automatic Dev Setup
# Purpose: Configure general development runtimes (Node.js, Go, Rust, Ruby, JVM, frontend tooling).
# Version: 3.0.0
# Dependencies: bash, brew, nvm, rustup, rbenv
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M05}"

ensure_brew_formula() {
    local formula="$1"
    local friendly="${2:-$1}"
    local short_name="${formula##*/}"
    if ! brew list --formula "$short_name" >/dev/null 2>&1; then
        log_info "Installing required Homebrew formula: ${friendly}"
        if ! ads_retry "brew install ${formula}" brew install "$formula"; then
            log_warning "Unable to install ${friendly}; related tooling may be unavailable."
            return 1
        fi
    fi
}

setup_nvm() {
    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    export NVM_DIR="$nvm_dir"
    ads_ensure_directory "$nvm_dir"
    local nvm_init="/opt/homebrew/opt/nvm/nvm.sh"
    if [[ ! -f "$nvm_init" ]]; then
        log_warning "nvm initialisation script not found at $nvm_init. Attempting Homebrew remediation."
        if ! brew list --formula nvm >/dev/null 2>&1; then
            ads_retry "brew install nvm" brew install nvm || log_warning "Homebrew failed to install nvm."
        fi
    fi
    if [[ ! -f "$nvm_init" ]]; then
        log_error "nvm initialisation script still missing at $nvm_init after remediation."
        return 1
    fi
    # shellcheck disable=SC1090
    source "$nvm_init"
    if ! command -v nvm >/dev/null 2>&1; then
        log_error "nvm command not available after sourcing $nvm_init."
        return 1
    fi
    ads_retry "nvm install 20" nvm install 20
    nvm alias default 20 >/dev/null 2>&1 || log_warning "Unable to set nvm default alias."
    nvm use default >/dev/null 2>&1 || log_warning "Unable to switch to default Node.js version."
    npm install -g yarn pnpm >/dev/null 2>&1 || log_warning "npm global package installation encountered issues."
}

setup_rust() {
    if command -v rustup >/dev/null 2>&1; then
        rustup update
    else
        if ! command -v rustup-init >/dev/null 2>&1; then
            ensure_brew_formula "rustup-init" "rustup-init"
        fi
        if command -v rustup-init >/dev/null 2>&1; then
            rustup-init -y --no-modify-path
            export PATH="$HOME/.cargo/bin:$PATH"
        else
            log_warning "rustup-init not available; skipping Rust toolchain bootstrap."
            return
        fi
    fi

    if command -v rustup >/dev/null 2>&1; then
        rustup default stable
    else
        log_warning "rustup command unavailable; Rust toolchain may be incomplete."
        return
    fi

    if command -v cargo >/dev/null 2>&1; then
        cargo install cargo-edit >/dev/null 2>&1 || log_warning "cargo-edit installation skipped."
    else
        log_warning "cargo executable not detected; skipping cargo-edit installation."
    fi
}

setup_go() {
    local go_path="${GOPATH:-$HOME/go}"
    export GOPATH="$go_path"
    ads_ensure_directory "$GOPATH"

    if ! command -v go >/dev/null 2>&1; then
        ensure_brew_formula "go" "Go"
    fi

    if ! command -v go >/dev/null 2>&1; then
        log_warning "Go binary not available; skipping Go configuration."
        return
    fi

    go env -w GOPATH="$GOPATH" >/dev/null 2>&1 || log_warning "Unable to persist GOPATH via go env."
    go env -w GOBIN="$GOPATH/bin" >/dev/null 2>&1 || log_warning "Unable to persist GOBIN via go env."
    go install golang.org/x/tools/gopls@latest >/dev/null 2>&1 || log_warning "Failed to install gopls language server."
    go install golang.org/x/tools/cmd/goimports@latest >/dev/null 2>&1 || log_warning "Failed to install goimports."
}

setup_ruby() {
    if ! command -v rbenv >/dev/null 2>&1; then
        log_warning "rbenv not installed; skipping Ruby setup."
        return
    fi

    eval "$(rbenv init -)"
    local ruby_version="3.3.4"
    if ! rbenv versions --bare | grep -q "$ruby_version"; then
        ensure_brew_formula "openssl@3" "openssl@3"
        local openssl_prefix
        openssl_prefix=$(brew --prefix openssl@3 2>/dev/null || true)
        if [[ -n "$openssl_prefix" ]]; then
            RUBY_CONFIGURE_OPTS="--with-openssl-dir=${openssl_prefix}" rbenv install "$ruby_version" || log_warning "rbenv failed to install Ruby ${ruby_version}."
        else
            rbenv install "$ruby_version" || log_warning "rbenv failed to install Ruby ${ruby_version}."
        fi
    fi
    if rbenv versions --bare | grep -q "$ruby_version"; then
        rbenv global "$ruby_version"
        gem install bundler --no-document >/dev/null 2>&1 || log_warning "Failed to install bundler gem."
    else
        log_warning "Ruby ${ruby_version} not present; global version unchanged."
    fi
}

setup_jvm() {
    log_info "Configuring JVM..."
    if ! ensure_brew_formula "openjdk" "OpenJDK"; then
        log_warning "OpenJDK installation failed. JVM-based tools will be unavailable."
        return 1
    fi

    local openjdk_prefix
    openjdk_prefix=$(brew --prefix openjdk)
    if [[ -n "$openjdk_prefix" ]]; then
        log_info "Symlinking OpenJDK to be discoverable by the system..."
        sudo ln -sfn "$openjdk_prefix/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk || log_warning "Failed to symlink OpenJDK."
    fi

    if command -v /usr/libexec/java_home >/dev/null 2>&1; then
        export JAVA_HOME=$(/usr/libexec/java_home)
        log_info "JAVA_HOME set to $JAVA_HOME"
    fi
}

setup_denobun() {
    if command -v deno >/dev/null 2>&1; then
        deno upgrade >/dev/null 2>&1 || true
    fi
    if command -v bun >/dev/null 2>&1; then
        bun upgrade >/dev/null 2>&1 || true
    fi
}

setup_container_tooling() {
    log_info "Preparing container and Kubernetes tooling..."
    if command -v colima >/dev/null 2>&1; then
        ads_ensure_directory "$HOME/.config/colima"
        local colima_profile="$HOME/.config/colima/default.yaml"
        local cpu="4"
        local memory="6"
        local disk="80"
        if [[ "$ADS_MODE" == "performance" ]]; then
            cpu="8"
            memory="12"
            disk="120"
        fi
        if [[ ! -f "$colima_profile" ]]; then
            cat > "$colima_profile" <<EOF
# Generated by Automatic Dev Setup
cpu: ${cpu}
memory: ${memory}
disk: ${disk}
arch: aarch64
features:
  - kubernetes
mounts:
  - location: ~/coding_environment
    writable: true
EOF
            log_info "Created default Colima profile with Kubernetes support."
        else
            log_info "Colima profile exists; leaving as-is."
        fi
    else
        log_warning "Colima not detected; install via Homebrew bundle to enable container virtualisation."
    fi

    if command -v kubectl >/dev/null 2>&1; then
        ads_ensure_directory "$HOME/.kube"
    fi

    if command -v helm >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/helm"
    fi
}

main() {
    log_header "[05] Development Stack"
    log_info "Development stack mode: ${ADS_MODE}"
    ads_require_command brew "Install Homebrew via module 02"
    setup_nvm || log_warning "nvm setup encountered issues."
    setup_rust
    setup_go
    setup_ruby
    setup_jvm
    setup_denobun
    setup_container_tooling
    log_success "Development stack configured."
}

main "$@"
