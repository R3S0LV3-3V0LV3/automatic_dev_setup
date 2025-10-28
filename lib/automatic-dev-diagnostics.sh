#!/usr/bin/env bash
# =============================================================================
# automatic-dev-diagnostics.sh - Automatic Dev Setup
# Purpose: Provide shared diagnostic metadata lookup utilities.
# Version: 3.1.0
# Dependencies: bash, awk
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ADS_FAILURE_CATALOG="${ADS_FAILURE_CATALOG:-$SUITE_ROOT/config/failure-catalog.tsv}"

_ads_failure_catalog_headers="code\tmodule_id\tmodule_name\tseverity\tcategory\tdoc_anchor\tsummary"

ads_failure_catalog_path() {
    printf '%s\n' "$ADS_FAILURE_CATALOG"
}

ads_failure_lookup() {
    local code="$1"
    [[ -z "$code" ]] && return 1
    local catalog
    catalog=$(ads_failure_catalog_path)
    [[ -f "$catalog" ]] || return 1

    awk -F $'\t' -v target="$code" '
        /^[[:space:]]*#/ { next }
        NF < 7 { next }
        $1 == target { print $0; exit 0 }
    ' "$catalog"
}

ads_failure_metadata() {
    local code="$1"
    local row
    row=$(ads_failure_lookup "$code") || return 1
    printf '%s\n' "$row"
}

ads_failure_field() {
    local code="$1"
    local field="$2"
    local row
    row=$(ads_failure_lookup "$code") || return 1
    case "$field" in
        code)        awk -F $'\t' '{print $1}' <<<"$row" ;;
        module_id)   awk -F $'\t' '{print $2}' <<<"$row" ;;
        module_name) awk -F $'\t' '{print $3}' <<<"$row" ;;
        severity)    awk -F $'\t' '{print $4}' <<<"$row" ;;
        category)    awk -F $'\t' '{print $5}' <<<"$row" ;;
        doc_anchor)  awk -F $'\t' '{print $6}' <<<"$row" ;;
        summary)     awk -F $'\t' '{print $7}' <<<"$row" ;;
        *)
            return 1
            ;;
    esac
}

ads_failure_doc_reference() {
    local code="$1"
    local anchor
    anchor=$(ads_failure_field "$code" doc_anchor) || return 1
    local docs_dir="${ADS_DOCS_DIR:-$SUITE_ROOT/docs}"
    if [[ -z "$anchor" ]]; then
        printf '%s/TROUBLESHOOTING.md\n' "$docs_dir"
        return 0
    fi
    printf '%s/TROUBLESHOOTING.md%s\n' "$docs_dir" "$anchor"
}

ads_failure_summary_line() {
    local code="$1"
    local module_name severity category summary
    module_name=$(ads_failure_field "$code" module_name 2>/dev/null || echo "Unknown module")
    severity=$(ads_failure_field "$code" severity 2>/dev/null || echo "unknown")
    category=$(ads_failure_field "$code" category 2>/dev/null || echo "uncategorised")
    summary=$(ads_failure_field "$code" summary 2>/dev/null || echo "No summary available.")
    printf '[%s] %s | severity=%s category=%s | %s\n' "$code" "$module_name" "$severity" "$category" "$summary"
}

ads_generate_resource_assessment_doc() {
    local log_root="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
    local telemetry_log="${ADS_TELEMETRY_LOG:-$log_root/failure-events.jsonl}"
    local resource_assessment_doc
    resource_assessment_doc="${log_root}/resource-assessment-$(date +%Y%m%d-%H%M%S).md"

    if [[ ! -f "$telemetry_log" ]]; then
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        >&2 printf 'Skipping resource assessment generation (jq not installed).\n'
        return 0
    fi

    mkdir -p "$log_root"

    local resource_warnings
    resource_warnings=$(grep -E '"code":"ADS-R[0-9]+' "$telemetry_log" || true)

    if [[ -z "$resource_warnings" ]]; then
        return 0
    fi

    local table_rows
    if ! table_rows=$(printf '%s\n' "$resource_warnings" | jq -r '"| \(.timestamp) | \(.code) | \(.severity) | \(.category) | \(.location) | \(.summary) | \(.context) |"'); then
        >&2 printf 'Failed to parse telemetry log for resource assessment generation.\n'
        return 0
    fi

    cat > "$resource_assessment_doc" <<EOF
# Automatic Dev Setup - Resource Assessment

This document summarizes the resource-related warnings that were generated during the execution of the script.

| Timestamp | Code | Severity | Category | Location | Summary | Context |
|---|---|---|---|---|---|---|
$table_rows
EOF
}
