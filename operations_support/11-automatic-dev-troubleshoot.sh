#!/usr/bin/env bash
# =============================================================================
# 11-automatic-dev-troubleshoot.sh - Wrapper for repository troubleshooting tool
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$REPO_ROOT/troubleshooting.sh" "$@"
