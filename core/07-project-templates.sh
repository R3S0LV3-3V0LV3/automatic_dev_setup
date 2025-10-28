#!/usr/bin/env bash
# =============================================================================
# 07-project-templates.sh - Automatic Dev Setup
# Purpose: Provision reusable project templates and cheatsheets for rapid onboarding.
# Version: 3.0.0
# Dependencies: bash, rsync, mkdir
# Criticality: BETA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M07}"

sync_templates() {
    ads_ensure_directory "$ADS_TEMPLATE_DEST"
    log_info "Syncing templates to $ADS_TEMPLATE_DEST"
    rsync -a --delete "$ADS_TEMPLATE_ROOT/" "$ADS_TEMPLATE_DEST/"
}

main() {
    log_header "[07] Project Templates"
    sync_templates
    log_success "Project templates synchronised."
}

main "$@"
