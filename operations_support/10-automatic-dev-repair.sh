#!/usr/bin/env bash
# =============================================================================
# 10-automatic-dev-repair.sh - Automatic Dev Setup
# Purpose: Reconcile preconfigured Macs by reapplying Automatic Dev Setup modules and rerunning validation.
# Version: 3.0.0
# Dependencies: bash
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"
ORCHESTRATOR_INSTALL="$ADS_INSTALL_ROOT/core/00-automatic-dev-orchestrator.sh"
ORCHESTRATOR_LOCAL="$REPO_ROOT/core/00-automatic-dev-orchestrator.sh"
VALIDATE_INSTALL="$ADS_INSTALL_ROOT/operations_support/09-automatic-dev-validate.sh"
VALIDATE_LOCAL="$REPO_ROOT/operations_support/09-automatic-dev-validate.sh"
MODE="${ADS_MODE:-standard}"

usage() {
    cat <<'EOF'
Automatic Dev Setup Repair Utility

Usage: ./10-automatic-dev-repair.sh [--standard|--performance|--mode <value>]

This script:
  1. Re-runs the orchestrator in the requested mode (default: standard).
  2. Executes the validation suite afterwards to confirm drift-free state.
EOF
}

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
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

export ADS_MODE="$MODE"

if [[ -x "$ORCHESTRATOR_LOCAL" ]]; then
    ORCHESTRATOR="$ORCHESTRATOR_LOCAL"
else
    ORCHESTRATOR="$ORCHESTRATOR_INSTALL"
fi

if [[ -x "$VALIDATE_LOCAL" ]]; then
    VALIDATE="$VALIDATE_LOCAL"
else
    VALIDATE="$VALIDATE_INSTALL"
fi

echo "[Repair] Reapplying Automatic Dev Setup in '${MODE}' mode..."
if ! bash "$ORCHESTRATOR" --mode "$MODE"; then
    echo "[Repair] Orchestrator run failed." >&2
    exit 1
fi

echo "[Repair] Running validation suite..."
if ! bash "$VALIDATE" --mode "$MODE"; then
    echo "[Repair] Validation suite reported failures." >&2
    exit 1
fi

echo "[Repair] Completed. Review logs in ${ADS_LOG_ROOT} for details."
