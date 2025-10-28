#!/usr/bin/env bash
# =============================================================================
# 04-automatic-dev-python.sh - Wrapper for Python ecosystem module
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$REPO_ROOT/core/00-automatic-dev-orchestrator.sh" --only "04-python-ecosystem" "$@"
