#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# =============================================================================
# automatic-dev-env.sh - Automatic Dev Setup
# Purpose: Provide a single entry point for sourcing the ADS environment.
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'automatic-dev-env.sh must be sourced, not executed directly.\n' >&2
    exit 1
fi

if [[ -n "${ADS_ENV_SH_LOADED:-}" ]]; then
    return 0
fi
ADS_ENV_SH_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export ADS_SUITE_ROOT="$SUITE_ROOT"
source "$SUITE_ROOT/automatic-dev-config.env"
source "$SUITE_ROOT/lib/automatic-dev-logging.sh"
source "$SUITE_ROOT/lib/automatic-dev-error-handling.sh"
source "$SUITE_ROOT/lib/automatic-dev-core.sh"
source "$SUITE_ROOT/lib/automatic-dev-validation.sh"
