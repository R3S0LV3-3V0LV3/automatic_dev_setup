#!/usr/bin/env bash
# =============================================================================
# automatic-dev-validation.sh - Automatic Dev Setup
# Purpose: Provide preflight and post-install validation utilities.
# Version: 3.0.0
# Dependencies: bash, sw_vers, uname, df, ping, id
# Criticality: ALPHA
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'automatic-dev-validation.sh must be sourced, not executed directly.\n' >&2
    exit 1
fi

if [[ -n "${ADS_VALIDATION_SH_LOADED:-}" ]]; then
    return 0
fi
ADS_VALIDATION_SH_LOADED=1

set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck source=automatic-dev-suite/lib/automatic-dev-core.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/automatic-dev-core.sh"



ads_validate_macos_version() {
    local version
    version=$(ads_detect_macos_version)
    if [[ "$version" == "UNKNOWN" ]]; then
        log_error "Unable to determine macOS version."
        return 1
    fi
    local major="${version%%.*}"
    if (( major < 12 )); then
        log_error "macOS $version detected. Version 12 or newer required."
        return 1
    fi
    log_success "macOS version: $version"
}

ads_validate_architecture() {
    ads_require_arm64
    log_info "Detected architecture: $(ads_detect_arch)"
}

ads_validate_disk_space() {
    local available
    available=$(df -g "$HOME" | awk 'NR==2 {print $4}')
    if [[ -z "$available" ]]; then
        log_warning "Unable to determine disk space."
        return 0
    fi
    if (( available < ADS_MIN_DISK_GB )); then
        log_error "Available disk space ${available}GB is below minimum ${ADS_MIN_DISK_GB}GB."
        return 1
    elif (( available < ADS_MIN_RECOMMENDED_DISK_GB )); then
        if [[ "${IGNORE_RESOURCE_WARNINGS:-0}" -eq 0 ]]; then
            log_warning "Available disk space ${available}GB below recommended ${ADS_MIN_RECOMMENDED_DISK_GB}GB."
            ads_record_failure_event "ADS-R01" "disk_space" "Available disk space ${available}GB below recommended ${ADS_MIN_RECOMMENDED_DISK_GB}GB."
        fi
    else
        log_success "Available disk space: ${available}GB"
    fi
}

ads_validate_memory() {
    local total_bytes
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    local total_gb
    total_gb=$((total_bytes / 1024 / 1024 / 1024))
    if (( total_gb < ADS_MIN_RAM_GB )); then
        if [[ "${IGNORE_RESOURCE_WARNINGS:-0}" -eq 0 ]]; then
            log_warning "System memory ${total_gb}GB below recommended ${ADS_MIN_RAM_GB}GB."
            ads_record_failure_event "ADS-R02" "memory" "System memory ${total_gb}GB below recommended ${ADS_MIN_RAM_GB}GB."
        fi
    else
        log_success "System memory: ${total_gb}GB"
    fi
}

ads_validate_network() {
    if ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
        log_success "Network connectivity validated (8.8.8.8 reachable)."
    else
        log_warning "Unable to reach 8.8.8.8. Check network connectivity."
    fi
}

ads_validate_admin() {
    if groups "$USER" | grep -q admin; then
        log_success "User $USER has admin privileges."
        return 0
    fi
    log_error "User $USER lacks admin privileges. Add user to admin group."
    return 1
}

ads_validate_xcode_select() {
    if xcode-select -p >/dev/null 2>&1; then
        log_success "Xcode Command Line Tools already installed."
        return 0
    fi
    log_info "Installing Xcode Command Line Tools (may require GUI confirmation)..."
    xcode-select --install >/dev/null 2>&1 || log_warning "xcode-select installation initiated or already in progress."
}

ads_run_preflight_checks() {
    ads_validate_macos_version
    ads_validate_architecture
    ads_validate_disk_space
    ads_validate_memory
    ads_validate_network
    ads_validate_admin
    ads_validate_xcode_select
}
