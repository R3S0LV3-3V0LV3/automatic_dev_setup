#!/usr/bin/env bash
# =============================================================================
# automatic-dev-logging.sh - Automatic Dev Setup
# Purpose: Provide standardised logging utilities with audit-grade features.
# Version: 3.0.0
# Dependencies: bash, date, mkdir, tee
# Criticality: ALPHA
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'automatic-dev-logging.sh must be sourced, not executed directly.\n' >&2
    exit 1
fi

if [[ -n "${ADS_LOGGING_SH_LOADED:-}" ]]; then
    return 0
fi
ADS_LOGGING_SH_LOADED=1

set -Eeuo pipefail
IFS=$'\n\t'

ADS_LOG_ROOT="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
ADS_LOG_FILE="${ADS_LOG_FILE:-$ADS_LOG_ROOT/automatic-dev-$(date -u '+%Y%m%d').log}"

_ads_init_logs() {
    mkdir -p "$ADS_LOG_ROOT"
    # Retain logs for 30 days
    find "$ADS_LOG_ROOT" -type f -name 'automatic-dev-*.log' -mtime +30 -delete 2>/dev/null || true
    # Rotate logs larger than 100MB
    if [[ -f "$ADS_LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$ADS_LOG_FILE" 2>/dev/null || stat -c%s "$ADS_LOG_FILE")
        if [[ "${size:-0}" -ge $((100 * 1024 * 1024)) ]]; then
            mv "$ADS_LOG_FILE" "${ADS_LOG_FILE%.log}-$(date -u '+%H%M%S').log"
        fi
    fi
    touch "$ADS_LOG_FILE"
}

_ads_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

_ads_context() {
    printf 'user=%s pid=%s' "$(id -un)" "$$"
}

_ads_log() {
    local level="$1"
    local message="$2"
    local colour="$3"
    local emoji="$4"

    local timestamp
    timestamp=$(_ads_timestamp)
    local context
    context=$(_ads_context)

    local log_line
    log_line="[$timestamp] [$level] [$context] $message"

    # Console output with colourised summary
    if [[ -t 1 ]]; then
        printf '%b%s%b %s\n' "$colour" "$emoji" '\033[0m' "$message"
    else
        printf '%s %s\n' "$emoji" "$message"
    fi

    # Append to log file without colour codes
    printf '%s\n' "$log_line" >> "$ADS_LOG_FILE" || {
        _ads_init_logs
        printf '%s\n' "$log_line" >> "$ADS_LOG_FILE" || {
            >&2 printf 'Logging failure: unable to write to %s\n' "$ADS_LOG_FILE"
        }
    }
}

log_info()        { _ads_log "INFO" "${1//[$'\r\n']/ }" '\033[0;34m' "[INFO]"; }
log_success()     { _ads_log "SUCCESS" "${1//[$'\r\n']/ }" '\033[0;32m' "[SUCCESS]"; }
log_warning()     { _ads_log "WARNING" "${1//[$'\r\n']/ }" '\033[1;33m' "[WARN]"; }
log_error()       { _ads_log "ERROR" "${1//[$'\r\n']/ }" '\033[0;31m' "[ERROR]"; }
log_fatal()       { _ads_log "FATAL" "${1//[$'\r\n']/ }" '\033[0;31m' "[FATAL]"; exit 1; }
log_debug() {
    if [[ "${ADS_DEBUG:-${DEBUG:-0}}" == "1" ]]; then
        _ads_log "DEBUG" "${1//[$'\r\n']/ }" '\033[0;36m' "[DBG]"
    fi
    return 0
}
log_header()      { _ads_log "HEADER" "${1//[$'\r\n']/ }" '\033[0;35m' "[HDR]"; }
log_performance() {
    local label="$1"
    local duration="$2"
    _ads_log "PERF" "${label//[$'\r\n']/ } completed in ${duration}s" '\033[0;36m' "[PERF]"
}

ads_log_section() {
    local section="$1"
    log_header "===== ${section} ====="
}

ads_rotate_telemetry() {
    local log_root="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
    local failure_log="${ADS_FAILURE_LOG:-$log_root/failure-codes.log}"
    local telemetry_log="${ADS_TELEMETRY_LOG:-$log_root/failure-events.jsonl}"
    local max_size=$((10 * 1024 * 1024)) # 10MB

    if [[ -f "$failure_log" ]]; then
        local size
        size=$(stat -f%z "$failure_log" 2>/dev/null || stat -c%s "$failure_log")
        if [[ "${size:-0}" -ge $max_size ]]; then
            mv "$failure_log" "${failure_log%.log}-$(date -u '+%Y%m%d%H%M%S').log"
            touch "$failure_log"
        fi
    fi

    if [[ -f "$telemetry_log" ]]; then
        local size
        size=$(stat -f%z "$telemetry_log" 2>/dev/null || stat -c%s "$telemetry_log")
        if [[ "${size:-0}" -ge $max_size ]]; then
            mv "$telemetry_log" "${telemetry_log%.jsonl}-$(date -u '+%Y%m%d%H%M%S').jsonl"
            touch "$telemetry_log"
        fi
    fi

    find "$log_root" -type f -name 'test-report-*.md' -mtime +30 -delete 2>/dev/null || true
}

_ads_init_logs
