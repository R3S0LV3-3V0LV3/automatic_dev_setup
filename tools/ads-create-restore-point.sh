#!/usr/bin/env bash
# =============================================================================
# ads-create-restore-point.sh - Automatic Dev Setup
# Purpose: Manually trigger restore point creation for critical files.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=automatic-dev-suite/lib/automatic-dev-env.sh
source "$SUITE_ROOT/lib/automatic-dev-env.sh"

label="${1:-manual}"
shift || true

if ! ads_create_restore_point "$label" "$@"; then
    log_error "Restore point creation failed."
    exit 1
fi
