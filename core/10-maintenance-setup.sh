#!/usr/bin/env bash
# =============================================================================
# 10-maintenance-setup.sh - Automatic Dev Setup
# Purpose: Configure maintenance tooling, automated updates, and backup scaffolding.
# Version: 3.0.0
# Dependencies: bash, launchctl
# Criticality: BETA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M10}"

configure_launchd_job() {
    local plist="$ADS_MAINTENANCE_ROOT/com.automatic-dev.maintenance.plist"
    ads_ensure_directory "$ADS_MAINTENANCE_ROOT"
    ads_ensure_directory "$ADS_LOG_ROOT"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.automatic-dev.maintenance</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>brew update && brew upgrade && brew cleanup && pipx upgrade-all</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key>
      <integer>3</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$ADS_LOG_ROOT/maintenance.log</string>
    <key>StandardErrorPath</key>
    <string>$ADS_LOG_ROOT/maintenance.err</string>
    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
EOF
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
}

create_backup_structure() {
    ads_ensure_directory "$ADS_BACKUP_DIR/projects"
    ads_ensure_directory "$ADS_BACKUP_DIR/databases"
    ads_ensure_directory "$ADS_BACKUP_DIR/config"
}

main() {
    log_header "[10] Maintenance Setup"
    configure_launchd_job
    create_backup_structure
    log_success "Maintenance framework configured."
}

main "$@"
