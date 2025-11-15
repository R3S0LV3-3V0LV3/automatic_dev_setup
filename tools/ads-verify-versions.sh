#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
# =============================================================================
# ads-verify-versions.sh - Automatic Dev Setup
# Purpose: Verify that tool versions match the expected lock catalogue.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=automatic-dev-suite/lib/automatic-dev-env.sh
source "$SUITE_ROOT/lib/automatic-dev-env.sh"

run_verification() {
    local LOCK_FILE="${ADS_VERSION_LOCK_FILE}"
    local REPORT_DIR="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
    local REPORT_PATH
    REPORT_PATH="${REPORT_DIR}/version-lock-report-$(date -u '+%Y%m%d-%H%M%S').md"
    
    ads_ensure_directory "$REPORT_DIR"

    local pass=0
    local fail=0

    {
        printf '# Version Lock Verification\n\n'
        printf '| Component | Command | Expected | Result |\n'
        printf '|---|---|---|---|\n'
    } > "$REPORT_PATH"

    if [[ ! -f "$LOCK_FILE" ]]; then
        log_error "Version lock file missing at ${LOCK_FILE}."
        return 1
    fi

    # Read TSV file with proper field handling
    while IFS=$'\t' read -r component command expected _note; do
        # Skip empty lines and comments
        [[ -z "$component" || "$component" =~ ^# ]] && continue

        local output status first_line
        
        # Execute command and capture result
        set +e
        output=$(eval "$command" 2>&1)
        status=$?
        set -e
        
        # Extract first line of output
        first_line=$(printf '%s\n' "$output" | head -n 1)

        if [[ $status -ne 0 ]]; then
            log_error "${component}: command failed (${command})"
            printf '| %s | `%s` | `%s` | ❌ %s |\n' "$component" "$command" "$expected" "command failed" >> "$REPORT_PATH"
            ((fail++)) || true
            continue
        fi

        # Check if output matches expected pattern
        if [[ "$first_line" =~ $expected ]]; then
            log_success "${component}: ${first_line}"
            printf '| %s | `%s` | `%s` | ✅ %s |\n' "$component" "$command" "$expected" "$first_line" >> "$REPORT_PATH"
            ((pass++)) || true
        else
            log_error "${component}: expected ${expected}, observed ${first_line}"
            printf '| %s | `%s` | `%s` | ❌ %s |\n' "$component" "$command" "$expected" "$first_line" >> "$REPORT_PATH"
            ((fail++)) || true
        fi
    done < "$LOCK_FILE"

    log_info "Version lock report written to ${REPORT_PATH}"
    
    if (( fail > 0 )); then
        log_error "${fail} version checks failed; see ${REPORT_PATH}."
        return 1
    fi
    
    log_success "All ${pass} version checks passed."
    return 0
}

# Main execution
run_verification
