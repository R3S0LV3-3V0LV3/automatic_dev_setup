#!/usr/bin/env bash
# =============================================================================
# 03-automatic-dev-shell.sh - Wrapper for shell environment module
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$REPO_ROOT/core/00-automatic-dev-orchestrator.sh" --only "03-shell-environment" "$@"
