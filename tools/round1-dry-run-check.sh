#!/usr/bin/env bash

• set -euo pipefail

  # 1. Preview orchestrator execution plan without touching the system
  ~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --dry-run --mode
  standard

  # 2. List the most recent validation reports (read-only)
  VALIDATION_LOG_DIR="${HOME}/.automatic_dev_setup/logs"
  find "${VALIDATION_LOG_DIR}" -name "test-report-*.md" -print0 | xargs -0 ls -lt 2>/dev/null | head -n 5 || echo No validation reports found.

  # 3. Review recent telemetry entries (read-only)
  tail -n 20 "${VALIDATION_LOG_DIR}/failure-events.jsonl" 2>/dev/null || echo No failure-events.jsonl log present.
  tail -n 20 "${VALIDATION_LOG_DIR}/failure-codes.log" 2>/dev/null || echo No failure-codes.log present.