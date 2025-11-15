#!/usr/bin/env bash
# shellcheck disable=SC1091
# =============================================================================
# 08-system-optimisation.sh - Automatic Dev Setup
# Purpose: Apply performance tuning, cache management, and power optimisations.
# Version: 3.0.0
# Dependencies: bash, sudo, brew
# Criticality: BETA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M08}"
MODE="${ADS_MODE:-standard}"

apply_pmset() {
    local key="$1"
    local value="$2"
    if ! sudo pmset -a "$key" "$value"; then
        log_warning "pmset failed for ${key} ${value}"
    fi
}

cleanup_brew() {
    log_info "Running Homebrew cleanup procedures..."
    brew cleanup -s || log_warning "brew cleanup encountered warnings."
    brew autoremove || log_warning "brew autoremove encountered warnings."
}

purge_user_caches() {
    log_info "Purging user caches > 30 days..."
    find "$HOME/Library/Caches" -type f -mtime +30 -delete 2>/dev/null || true
}

optimise_power_settings() {
    ads_require_sudo
    if [[ "$MODE" == "performance" ]]; then
        apply_pmset displaysleep 0
        apply_pmset disksleep 0
        apply_pmset powernap 0
        apply_pmset autopoweroff 0
        apply_pmset standby 0
    else
        apply_pmset displaysleep 15
        apply_pmset disksleep 10
        apply_pmset powernap 0
    fi
}

flush_dns_cache() {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder || true
}

main() {
    log_header "[08] System Optimisation"
    log_info "Optimisation mode: ${MODE}"
    cleanup_brew
    purge_user_caches
    optimise_power_settings
    flush_dns_cache
    log_success "System optimisations applied."
}

main "$@"
