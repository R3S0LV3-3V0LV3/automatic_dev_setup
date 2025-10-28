#!/usr/bin/env bash
# =============================================================================
# automatic-dev-error-handling.sh - Automatic Dev Setup
# Purpose: Provide standardised error handling and trap utilities.
# Version: 3.0.0
# Dependencies: bash, date
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck source=automatic-dev-suite/lib/automatic-dev-logging.sh
# shellcheck source=automatic-dev-suite/lib/automatic-dev-diagnostics.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/automatic-dev-logging.sh"
source "$SCRIPT_DIR/automatic-dev-diagnostics.sh"

ADS_FAILURES=0
ADS_RECOVERY_ATTEMPTS="${ADS_RECOVERY_ATTEMPTS:-3}"

ads_init_telemetry() {
    local log_root="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
    local failure_log="${ADS_FAILURE_LOG:-$log_root/failure-codes.log}"
    local telemetry_log="${ADS_TELEMETRY_LOG:-$log_root/failure-events.jsonl}"
    mkdir -p "$log_root"
    touch "$failure_log"
    touch "$telemetry_log"
}

ads_record_failure_event() {
    local code="${1:-ADS-UNSET}"
    local location="${2:-unknown}"
    local context="${3:-}"
    local log_root="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
    local failure_log="${ADS_FAILURE_LOG:-$log_root/failure-codes.log}"
    mkdir -p "$log_root"

    local metadata
    metadata=$(ads_failure_metadata "$code" 2>/dev/null || true)
    local module_id module_name severity category summary
    if [[ -n "$metadata" ]]; then
        IFS=$'\t' read -r _ module_id module_name severity category _ summary <<<"$metadata"
    else
        module_id=""
        module_name=""
        severity="unknown"
        category="uncategorised"
        summary=""
    fi
    local doc_reference
    doc_reference=$(ads_failure_doc_reference "$code" 2>/dev/null || echo "")

    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    local hostname_short
    hostname_short="$(hostname -s 2>/dev/null || echo unknown)"
    local clean_context="${context//[$'\n\r\t']/ }"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$timestamp" \
        "$hostname_short" \
        "$code" \
        "$severity" \
        "$category" \
        "$location" \
        "$module_id" \
        "$module_name" \
        "$doc_reference" \
        "$clean_context" >> "$failure_log"

    local telemetry_log="${ADS_TELEMETRY_LOG:-$log_root/failure-events.jsonl}"
    local summary_compact="${summary//[$'\n\r\t']/ }"
    local telemetry_context="${clean_context//\"/\\\"}"
    local telemetry_summary="${summary_compact//\"/\\\"}"
    local telemetry_location="${location//\"/\\\"}"
    local telemetry_doc="${doc_reference//\"/\\\"}"
    printf '{"timestamp":"%s","host":"%s","code":"%s","severity":"%s","category":"%s","location":"%s","module_id":"%s","module_name":"%s","doc":"%s","summary":"%s","context":"%s"}\n' \
        "$timestamp" \
        "$hostname_short" \
        "$code" \
        "$severity" \
        "$category" \
        "$telemetry_location" \
        "$module_id" \
        "$module_name" \
        "$telemetry_doc" \
        "$telemetry_summary" \
        "$telemetry_context" >> "$telemetry_log"
}

ads_on_error() {
    local exit_code=$?
    local line_number=${BASH_LINENO[0]}
    local command=${BASH_COMMAND:-"<unknown>"}
    ((ADS_FAILURES++))
    log_error "Failure detected (exit=${exit_code}) at line ${line_number}: ${command}"
    log_error "Refer to docs/TROUBLESHOOTING.md for remediation steps."
    local failure_code="${ADS_FAILURE_CODE:-ADS-UNSET}"
    ads_record_failure_event "$failure_code" "line:${line_number}" "$command"
    local summary_line
    summary_line=$(ads_failure_summary_line "$failure_code" 2>/dev/null || true)
    if [[ -n "$summary_line" ]]; then
        log_warning "$summary_line"
        local doc_ref
        doc_ref=$(ads_failure_doc_reference "$failure_code" 2>/dev/null || echo "")
        if [[ -n "$doc_ref" ]]; then
            log_info "Diagnostic reference: $doc_ref"
        fi
    fi
    local base_dir="${ADS_INSTALL_ROOT:-$HOME/automatic_dev_setup}"
    local troubleshoot_path="$base_dir/troubleshooting.sh"
    local repo_root
    repo_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    local local_troubleshooter="$repo_root/troubleshooting.sh"
    if [[ -x "$local_troubleshooter" ]]; then
        troubleshoot_path="$local_troubleshooter"
    fi
    log_info "Run ${troubleshoot_path} for guided recovery."
    exit 1
}

ads_on_exit() {
    local exit_code=$?

    local latest_report
    if compgen -G "$ADS_LOG_ROOT/test-report-*.md" >/dev/null 2>&1; then
        latest_report=$(ls -t "$ADS_LOG_ROOT"/test-report-*.md 2>/dev/null | head -n 1 || true)
    else
        latest_report=""
    fi
    if [[ -z "$latest_report" ]]; then
        local report_file
        report_file="$ADS_LOG_ROOT/test-report-$(date +%Y%m%d-%H%M%S)-provisional.md"
        ads_ensure_directory "$ADS_LOG_ROOT"
        if [[ "${ADS_DEBUG:-${DEBUG:-0}}" == "1" ]]; then
            log_debug "Creating provisional report file: $report_file"
        fi
        cat > "$report_file" <<EOF
# Automatic Dev Setup - Test Report (Provisional)

This is a provisional report. The validation suite (module 09) did not run or did not complete.
EOF
    fi

    if [[ $exit_code -ne 0 ]]; then
        log_fatal "Script terminated with exit code ${exit_code}"
    else
        log_success "Script completed successfully"
    fi
}

ads_enable_traps() {
    trap ads_on_error ERR
    trap ads_on_exit EXIT
}

ads_disable_traps() {
    trap - ERR EXIT
}
