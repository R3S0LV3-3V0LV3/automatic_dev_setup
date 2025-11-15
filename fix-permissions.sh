#!/usr/bin/env bash
# =============================================================================
# fix-permissions.sh - Automatic Dev Setup Permission Fixer
# Author: Kieran Tandi
# Purpose: Quickly fix all file permissions in the repository
# Version: 1.0.0
# Dependencies: bash, chmod, find
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simple logging functions for standalone use
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

fix_permissions() {
    local count=0
    
    log_info "Fixing permissions for Automatic Dev Setup repository..."
    
    # Clear Gatekeeper quarantine attributes
    log_info "Clearing Gatekeeper quarantine attributes..."
    xattr -dr com.apple.quarantine "$REPO_ROOT" 2>/dev/null || true
    
    # Make all .sh files executable
    log_info "Making all shell scripts executable..."
    
    # Method 1: Using find (most reliable)
    if command -v find >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do
            if [[ ! -x "$file" ]]; then
                chmod +x "$file"
                ((count++))
            fi
        done < <(find "$REPO_ROOT" -type f -name '*.sh' -print0 2>/dev/null)
    else
        # Method 2: Using glob patterns
        for file in "$REPO_ROOT"/*.sh "$REPO_ROOT"/**/*.sh; do
            if [[ -f "$file" && ! -x "$file" ]]; then
                chmod +x "$file"
                ((count++))
            fi
        done
    fi
    
    # Ensure config files are readable but not executable
    if [[ -f "$REPO_ROOT/automatic-dev-config.env" ]]; then
        chmod 644 "$REPO_ROOT/automatic-dev-config.env"
    fi
    
    # Ensure directories have proper permissions
    find "$REPO_ROOT" -type d -exec chmod 755 {} \; 2>/dev/null || true
    
    if [[ $count -gt 0 ]]; then
        log_success "Fixed permissions for $count shell scripts"
    else
        log_info "All shell scripts already have correct permissions"
    fi
    
    log_success "Permission fix complete!"
    log_info "You can now run: ./install.sh or ./preflight.sh"
}

# Main execution
fix_permissions