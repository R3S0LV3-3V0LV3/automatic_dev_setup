#!/usr/bin/env bash
# =============================================================================
# automatic-dev-env.sh - Automatic Dev Setup
# Purpose: Provide a single entry point for sourcing the ADS environment.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export ADS_SUITE_ROOT="$SUITE_ROOT"
source "$SUITE_ROOT/automatic-dev-config.env"
source "$SUITE_ROOT/lib/automatic-dev-logging.sh"
source "$SUITE_ROOT/lib/automatic-dev-error-handling.sh"
source "$SUITE_ROOT/lib/automatic-dev-core.sh"
source "$SUITE_ROOT/lib/automatic-dev-validation.sh"
