#!/usr/bin/env bash
# =============================================================================
# install.sh - Automatic Dev Setup bootstrapper
# Author: Kieran Tandi
# Purpose: Install the suite under ~/automatic_dev_setup, ensure executables are
#          initialised, and run the selected installer workflow.
# Version: 3.0.0
# Dependencies: bash, rsync, sudo
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Work out who's actually running this — could be sudo, could be direct
# We need the real user, not root masquerading as helpful
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(eval echo "~${SUDO_USER}")"
else
    TARGET_USER="$(id -un)"
    TARGET_HOME="$HOME"
fi

INSTALL_ROOT="${TARGET_HOME}/automatic_dev_setup"

MODE_ARGS=()
REPAIR=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --standard|--performance)
            MODE_ARGS+=("$1")
            shift
            ;;
        --mode)
            MODE_ARGS+=("$1" "$2")
            shift 2
            ;;
        --repair)
            REPAIR=1
            shift
            ;;
        *)
            MODE_ARGS+=("$1")
            shift
            ;;
    esac
done

request_sudo_upfront() {
    # Request sudo upfront and keep it alive throughout the script
    echo "[Setup] This installation requires administrator privileges for certain operations."
    echo "[Setup] You may be prompted for your password now."
    
    if ! sudo -v; then
        echo "[Setup] ERROR: Unable to obtain sudo privileges. Installation cannot proceed."
        exit 1
    fi
    
    # Keep sudo alive in background
    while true; do 
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_KEEPER_PID=$!
}

copy_suite() {
    if [[ "$REPO_ROOT" == "$INSTALL_ROOT" ]]; then
        echo "[Setup] Detected existing installation at $INSTALL_ROOT; skipping copy."
        return 0
    fi

    echo "[Setup] Installing Automatic Dev Setup into $INSTALL_ROOT"
    mkdir -p "$INSTALL_ROOT"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete \
            --exclude '.git/' \
            --exclude '.gitignore' \
            --exclude '.github/' \
            --exclude 'logs/' \
            "$REPO_ROOT/" "$INSTALL_ROOT/"
    else
        echo "[Setup] rsync not available; falling back to cp -R (no deletions)."
        cp -R "$REPO_ROOT/." "$INSTALL_ROOT/"
    fi

    if [[ "$(id -u)" -eq 0 ]]; then
        chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$INSTALL_ROOT"
    fi
}

ensure_executables() {
    echo "[Setup] Ensuring shell scripts are executable…"
    find "$INSTALL_ROOT" -type f -name "*.sh" -exec chmod 755 {} +
}

run_workflow() {
    local runner_path
    if (( REPAIR )); then
        runner_path="$INSTALL_ROOT/operations_support/10-automatic-dev-repair.sh"
    else
        runner_path="$INSTALL_ROOT/core/00-automatic-dev-orchestrator.sh"
    fi

    local cmd=("$runner_path" "${MODE_ARGS[@]}")

    if [[ "$(id -un)" != "$TARGET_USER" ]]; then
        echo "[Setup] Launching workflow as $TARGET_USER"
        sudo -H -u "$TARGET_USER" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

# Cleanup function to kill sudo keeper
cleanup() {
    if [[ -n "${SUDO_KEEPER_PID:-}" ]]; then
        kill "$SUDO_KEEPER_PID" 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
request_sudo_upfront
copy_suite
ensure_executables
run_workflow
