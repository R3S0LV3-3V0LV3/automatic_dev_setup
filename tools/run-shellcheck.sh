#!/usr/bin/env bash
# =============================================================================
# run-shellcheck.sh - Automatic Dev Setup
# Purpose: Run shellcheck on all shell scripts in the repository.
# =============================================================================

set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck is not installed. Please install it first."
    exit 1
fi

find . -type f -name "*.sh" -print0 | xargs -0 shellcheck
