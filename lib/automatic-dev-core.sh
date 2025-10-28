#!/usr/bin/env bash
# =============================================================================
# automatic-dev-core.sh - Automatic Dev Setup
# Purpose: Provide reusable helper utilities for all Automatic Dev Setup scripts.
# Version: 3.0.0
# Dependencies: bash, mkdir, stat, command
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck source=automatic-dev-suite/lib/automatic-dev-logging.sh
# shellcheck source=automatic-dev-suite/lib/automatic-dev-error-handling.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/automatic-dev-logging.sh"
source "$SCRIPT_DIR/automatic-dev-error-handling.sh"

ADS_MAX_RETRIES="${ADS_MAX_RETRIES:-3}"
ADS_RETRY_DELAY="${ADS_RETRY_DELAY:-5}"

ads_append_once() {
    local line="$1"
    local file="$2"
    [[ -z "$line" || -z "$file" ]] && { log_error "ads_append_once requires both a line and file path"; return 1; }
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if ! grep -Fqx "$line" "$file"; then
        printf '%s\n' "$line" >> "$file"
        log_debug "Appended line to $file: $line"
    fi
}

ads_ensure_directory() {
    local dir="$1"
    [[ -z "$dir" ]] && { log_error "ads_ensure_directory requires a directory path"; return 1; }
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

ads_require_command() {
    local cmd="$1"
    local package="${2:-}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [[ -n "$package" ]]; then
            log_error "Required command '$cmd' not found. Install: $package"
        else
            log_error "Required command '$cmd' not found."
        fi
        return 1
    fi
}

ads_retry() {
    local label="$1"
    shift
    local attempt=1
    local exit_code

    while (( attempt <= ADS_MAX_RETRIES )); do
        if "$@"; then
            log_success "$label succeeded on attempt $attempt"
            return 0
        fi
        exit_code=$?
        log_warning "$label failed on attempt $attempt (exit ${exit_code})"
        if (( attempt == ADS_MAX_RETRIES )); then
            log_error "$label exhausted retries"
            return "$exit_code"
        fi
        ((attempt++))
        sleep "$ADS_RETRY_DELAY"
    done
}

ads_run() {
    local label="$1"
    shift
    log_info "Executing: $label"
    "$@"
}

ads_measure() {
    local label="$1"
    shift
    local start
    local end
    start=$(date +%s)
    "$@"
    local cmd_exit_code=$?
    if [[ $cmd_exit_code -eq 0 ]]; then
        end=$(date +%s)
        local duration
        duration=$((end - start))
        log_performance "$label" "$duration"
        return 0
    else
        return "$cmd_exit_code"
    fi
}

ads_require_sudo() {
    # Check if we already have valid sudo credentials
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    
    # Check if we're in a context where sudo shouldn't be needed
    if [[ "${ADS_NO_SUDO:-0}" == "1" ]]; then
        log_debug "Sudo requirement bypassed (ADS_NO_SUDO=1)"
        return 0
    fi
    
    # Only request if we actually need it
    log_info "Administrator privileges required for this operation"
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi
    
    # Refresh sudo timestamp to extend timeout
    sudo -v
}

ads_backup_file() {
    local file="$1"
    [[ -z "$file" ]] && { log_error "ads_backup_file requires a file path"; return 1; }
    if [[ -f "$file" ]]; then
        local backup
        backup="${file}.backup.$(date -u '+%Y%m%d%H%M%S')"
        cp "$file" "$backup"
        log_info "Backup created: $backup"
    fi
}

ads_detect_arch() {
    uname -m
}

ads_detect_macos_version() {
    sw_vers -productVersion 2>/dev/null || echo "UNKNOWN"
}

ads_require_arm64() {
    local arch
    arch=$(ads_detect_arch)
    if [[ "$arch" != "arm64" ]]; then
        log_warning "Architecture '$arch' detected. Apple Silicon (arm64) recommended."
    fi
}
