#!/usr/bin/env bash
# =============================================================================
# 00-automatic-dev-orchestrator.sh - Automatic Dev Setup
# Purpose: Coordinate execution of all Automatic Dev Setup core modules in strict order.
# Version: 3.0.0
# Dependencies: bash, dirname, readlink, source, date
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUITE_ROOT="$REPO_ROOT"

source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
ads_init_telemetry
ads_rotate_telemetry

usage() {
    cat <<EOF
Automatic Dev Setup Orchestrator ${ADS_SUITE_VERSION}

Usage: $0 [options]

Modes:
  --standard         Balanced installation — sensible defaults, nothing excessive
  --performance      Full kit — monitoring tools, profilers, the works
  --mode <value>     Explicit mode selection (standard|performance)

Control Flow:
  --start <module>   Begin from specific module (e.g., 04-python-ecosystem)
  --only <module>    Execute single module in isolation
  --skip <module>    Bypass specific module (repeatable)
  --list             Show all available modules
  
Execution:
  --dry-run          Preview what would happen — no actual changes
  --ignore-resource-warnings  Override disk/memory checks (at your own risk)
  -h, --help         This message
EOF
}

declare -a ADS_MODULES=(
    "01-system-bootstrap"
    "02-homebrew-foundation"
    "03-shell-environment"
    "04-python-ecosystem"
    "05-development-stack"
    "06-database-systems"
    "07-project-templates"
    "08-system-optimization"
    "09-integration-validation"
    "10-maintenance-setup"
    "11-comprehensive-audit"
)

START_MODULE=""
ONLY_MODULE=""
declare -a SKIP_MODULES=()
DRY_RUN=0
MODE="${ADS_MODE:-standard}"
IGNORE_RESOURCE_WARNINGS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --standard)
            MODE="standard"
            shift
            ;;
        --performance)
            MODE="performance"
            shift
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --start)
            START_MODULE="$2"
            shift 2
            ;;
        --only)
            ONLY_MODULE="$2"
            shift 2
            ;;
        --skip)
            SKIP_MODULES+=("$2")
            shift 2
            ;;
        --list)
            printf 'Available modules:\n'
            for module in "${ADS_MODULES[@]}"; do
                printf '  - %s\n' "$module"
            done
            exit 0
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --ignore-resource-warnings)
            IGNORE_RESOURCE_WARNINGS=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

export IGNORE_RESOURCE_WARNINGS

case "$MODE" in
    standard|performance)
        export ADS_MODE="$MODE"
        ;;
    *)
        log_error "Invalid mode '$MODE'. Use --standard, --performance, or --mode <standard|performance>."
        exit 1
        ;;
esac

should_skip_module() {
    local module="$1"
    for skip in "${SKIP_MODULES[@]:-}"; do
        if [[ "$skip" == "$module" ]]; then
            return 0
        fi
    done
    return 1
}

resolve_module_path() {
    local module="$1"
    printf '%s/core/%s.sh\n' "$SUITE_ROOT" "$module"
}

log_header "Automatic Dev Setup v${ADS_SUITE_VERSION}"
log_info "Suite root: $SUITE_ROOT"
log_info "Execution mode: ${ADS_MODE}"

# Ensure we have sudo early — various modules will need it
if ! sudo -n true 2>/dev/null; then
    log_info "Note: Some operations require administrator privileges."
    log_info "Your password may be requested during installation."
fi

ads_run_preflight_checks

execute_modules() {
    local started=0
    for module in "${ADS_MODULES[@]}"; do
        local module_path
        module_path=$(resolve_module_path "$module")
        if [[ ! -f "$module_path" ]]; then
            log_error "Module missing: $module_path"
            exit 1
        fi

        if [[ -n "$ONLY_MODULE" && "$module" != "$ONLY_MODULE" ]]; then
            continue
        fi

        if [[ -n "$START_MODULE" && $started -eq 0 ]]; then
            if [[ "$module" == "$START_MODULE" ]]; then
                started=1
            else
                continue
            fi
        else
            started=1
        fi

        if should_skip_module "$module"; then
            log_warning "Skipping module: $module"
            continue
        fi

        local module_id="${module%%-*}"
        export ADS_FAILURE_CODE="ADS-M${module_id}"
        log_header "Module $module_id: $module"
        if (( DRY_RUN )); then
            log_info "[DRY RUN] Would execute: $module_path"
            continue
        fi

        ads_measure "$module" "$module_path"
        echo "ads_measure exit code: $?"
        export ADS_FAILURE_CODE="ADS-UNSET"
    done
}

execute_modules
echo "execute_modules completed."

ads_generate_resource_assessment_doc

log_success "Automatic Dev Setup completed."
