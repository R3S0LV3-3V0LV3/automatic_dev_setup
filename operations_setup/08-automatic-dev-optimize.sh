#!/usr/bin/env bash
# =============================================================================
# 08-automatic-dev-optimize.sh - Wrapper for optimisation module
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$REPO_ROOT/core/00-automatic-dev-orchestrator.sh" --only "08-system-optimization" "$@"
