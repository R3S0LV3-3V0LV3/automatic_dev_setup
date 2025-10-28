#!/usr/bin/env bash
# =============================================================================
# 09-automatic-dev-validate.sh - Wrapper for validation module
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
exec "$REPO_ROOT/core/00-automatic-dev-orchestrator.sh" --only "09-integration-validation" "$@"
