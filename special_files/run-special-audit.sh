#!/usr/bin/env bash
# =============================================================================
# run-special-audit.sh - Automatic Dev Setup
# Purpose: Perform an interactive, fully logged audit run that mirrors the
#          automatic_dev_setup installation and validation workflow. Each step
#          records verbose logs in timestamped folders under
#          ~/automatic_dev_setup/special_files/special_logs/.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ADS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_BASE="${HOME}/automatic_dev_setup/special_files"
DEFAULT_LOG_BASE="${DEFAULT_BASE}/special_logs"

INTERACTIVE=1
CUSTOM_LOG_ROOT=""

usage() {
    cat <<'EOF'
Automatic Dev Setup - Special Audit Run

Usage: run-special-audit.sh [options]

Options:
  --non-interactive        Execute every step without prompting (default: prompt before each step)
  --log-root <path>        Override the log destination (default: ~/automatic_dev_setup/special_files/special_logs)
  --help                   Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive)
            INTERACTIVE=0
            shift
            ;;
        --log-root)
            CUSTOM_LOG_ROOT="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

LOG_ROOT="${CUSTOM_LOG_ROOT:-$DEFAULT_LOG_BASE}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_ROOT="${LOG_ROOT}/audit_run_${RUN_ID}"

MASTER_LOG="${RUN_ROOT}/audit_run.log"
FAILED_LOG="${RUN_ROOT}/FAILED_STEPS.log"
SUMMARY_MD="${RUN_ROOT}/SUMMARY.md"

mkdir -p "$RUN_ROOT"
touch "$MASTER_LOG" "$FAILED_LOG"

log_master() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s | %s\n' "$timestamp" "$*" | tee -a "$MASTER_LOG"
}

prompt_yn() {
    local prompt="$1"
    local default="$2" # Y or N
    local suffix="[Y/n]"
    [[ "$default" == "N" ]] && suffix="[y/N]"

    if (( INTERACTIVE )); then
        local response response_lower
        while true; do
            read -r -p "${prompt} ${suffix} " response || response=""
            response="${response:-$default}"
            response_lower="$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')"
            case "$response_lower" in
                y|yes) return 0 ;;
                n|no)  return 1 ;;
                *) echo "Please answer yes or no." ;;
            esac
        done
    else
        [[ "$default" == "N" ]] && return 1 || return 0
    fi
}

STEP_SECTIONS=()
STEP_KEYS=()
STEP_DESCRIPTIONS=()
STEP_LOG_PATHS=()
STEP_CODES=()

join_command() {
    local parts=("$@")
    local result=""
    for arg in "${parts[@]}"; do
        result+="$(printf '%q ' "$arg")"
    done
    echo "${result% }"
}

run_step() {
    local section="$1"
    local key="$2"
    local description="$3"
    local default_choice="$4"
    shift 4

    local workdir="$ADS_ROOT"
    if [[ "${1:-}" == "--workdir" ]]; then
        workdir="$2"
        shift 2
    fi

    if [[ "${1:-}" != "--" ]]; then
        echo "Internal error: missing command delimiter for step '$key'." >&2
        exit 1
    fi
    shift
    if [[ $# -eq 0 ]]; then
        log_master "No command provided for step '${description}', skipping."
        return 0
    fi

    local command=("$@")
    local command_str
    command_str="$(join_command "${command[@]}")"

    local section_dir="${RUN_ROOT}/${section}"
    mkdir -p "$section_dir"
    local logfile="${section_dir}/${key}.log"

    log_master "STARTING: [${section}] ${description}"
    log_master "Command: ${command_str}"
    log_master "Log file: ${logfile}"

    if ! prompt_yn "Execute '${description}'?" "$default_choice"; then
        printf 'Step skipped by operator.\n' > "$logfile"
        STEP_SECTIONS+=("$section")
        STEP_KEYS+=("$key")
        STEP_DESCRIPTIONS+=("$description")
        STEP_LOG_PATHS+=("${logfile}")
        STEP_CODES+=("SKIPPED")
        log_master "SKIPPED: [${section}] ${description}"
        return 0
    fi

    local status
    set +e
    (
        cd "$workdir" || exit 1
        "${command[@]}"
    ) > >(tee "$logfile") 2> >(tee -a "$logfile" >&2)
    status=$?
    set -e

    STEP_SECTIONS+=("$section")
    STEP_KEYS+=("$key")
    STEP_DESCRIPTIONS+=("$description")
    STEP_LOG_PATHS+=("$logfile")
    STEP_CODES+=("$status")

    if (( status == 0 )); then
        log_master "SUCCESS: [${section}] ${description}"
    else
        log_master "FAILURE: [${section}] ${description} (exit ${status})"
        printf '[%s] %s | Log: %s | Exit: %s\n' "$section" "$description" "$logfile" "$status" >> "$FAILED_LOG"
        if prompt_yn "Continue after failure?" "Y"; then
            log_master "Continuing after failure of '${description}'."
        else
            log_master "Audit halted by operator after failure."
            finalize_run
            exit 1
        fi
    fi
}

generate_summary() {
    {
        echo "# Automatic Dev Setup - Special Audit Summary"
        echo
        echo "- Run ID: ${RUN_ID}"
        echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "- Repository: ${ADS_ROOT}"
        echo "- Script: ${SCRIPT_PATH}"
        echo "- Log root: ${RUN_ROOT}"
        echo
        echo "## Step Outcomes"
        echo
        echo "| Status | Section | Step | Log |"
        echo "|--------|---------|------|-----|"
        local total="${#STEP_SECTIONS[@]}"
        local rel_path
        for ((i = 0; i < total; i++)); do
            local code="${STEP_CODES[$i]}"
            local status_label
            case "$code" in
                0) status_label="✅ SUCCESS" ;;
                SKIPPED) status_label="⚪️ SKIPPED" ;;
                *) status_label="❌ FAIL (${code})" ;;
            esac
            rel_path="${STEP_LOG_PATHS[$i]#"$RUN_ROOT/"}"
            [[ -z "$rel_path" ]] && rel_path="(none)"
            echo "| ${status_label} | ${STEP_SECTIONS[$i]} | ${STEP_DESCRIPTIONS[$i]} | [log](${rel_path}) |"
        done
        echo
        if [[ -s "$FAILED_LOG" ]]; then
            echo "## Failed Steps"
            echo
            echo '```'
            cat "$FAILED_LOG"
            echo '```'
            echo
        fi
        echo "## Master Log"
        echo
        echo "[audit_run.log](audit_run.log)"
    } > "$SUMMARY_MD"
}

write_metadata() {
    local metadata="${RUN_ROOT}/run-metadata.json"
    {
        printf '{\n'
        printf '  "run_id": "%s",\n' "$RUN_ID"
        printf '  "timestamp": "%s",\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
        printf '  "repository_root": "%s",\n' "$ADS_ROOT"
        printf '  "script_path": "%s",\n' "$SCRIPT_PATH"
        printf '  "log_directory": "%s",\n' "$RUN_ROOT"
        printf '  "interactive": %s\n' "$((INTERACTIVE))"
        printf '}\n'
    } > "$metadata"
}

finalize_run() {
    write_metadata
    generate_summary
    log_master "SUMMARY: ${SUMMARY_MD}"
    log_master "FAILED STEPS LOG: ${FAILED_LOG}"
}

validate_telemetry_targets() {
    log_master "--- Phase: Telemetry Validation ---"
    local telemetry_missing=0
    local log_root="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"

    if [[ ! -f "${log_root}/failure-events.jsonl" ]]; then
        log_master "ERROR: Telemetry target missing: ${log_root}/failure-events.jsonl"
        telemetry_missing=1
    fi

    if [[ ! -f "${log_root}/failure-codes.log" ]]; then
        log_master "ERROR: Telemetry target missing: ${log_root}/failure-codes.log"
        telemetry_missing=1
    fi

    local latest_report
    latest_report=$(ls -t "${log_root}"/test-report-*.md 2>/dev/null | head -n 1)
    if [[ -z "$latest_report" ]]; then
        log_master "ERROR: Telemetry target missing: No test-report-*.md found in ${log_root}"
        telemetry_missing=1
    fi

    if (( telemetry_missing )); then
        log_master "FATAL: Aborting audit due to missing telemetry targets."
        exit 1
    fi
    log_master "SUCCESS: All telemetry targets are present."
}

log_system_state() {
    log_master "--- Phase: System State Snapshot ---"
    run_step "system_state" "system_overview" "Capture system overview" "Y" -- bash -lc "
echo '=== Automatic Dev Setup - System Snapshot ==='
echo \"Timestamp: \$(date '+%Y-%m-%d %H:%M:%S')\"
echo \"User: \$(id -un) (\$(id -u))\"
echo \"Hostname: \$(hostname)\"
echo \"Shell: ${SHELL}\"
echo \"Repository Root: ${ADS_ROOT}\"
echo
echo '--- Git Status ---'
if command -v git >/dev/null 2>&1; then
    git status --short --branch || true
    git rev-parse HEAD || true
else
    echo 'git not installed.'
fi
echo
echo '--- OS Information ---'
uname -a || true
if command -v sw_vers >/dev/null 2>&1; then
    sw_vers
fi
if command -v sysctl >/dev/null 2>&1; then
    mem_bytes=\$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    if [[ \"\$mem_bytes\" =~ ^[0-9]+$ ]]; then
        awk -v bytes=\"\$mem_bytes\" 'BEGIN { printf(\"Memory: %.2f GB\\n\", bytes/1024/1024/1024) }'
    fi
fi
df -h || true
echo
echo '--- ADS Environment ---'
env | grep '^ADS_' || echo 'No ADS_* variables set.'
"
    run_step "system_state" "brew_info" "Capture Homebrew environment" "Y" -- bash -lc "
if command -v brew >/dev/null 2>&1; then
    brew --version
    brew config || true
    brew list --versions || true
else
    echo 'brew not installed.'
fi
"
}

run_preinstall_checks() {
    log_master "--- Phase: Pre-Installation Checks ---"
    local section="pre_install"
    run_step "$section" "xcode_cli" "Ensure Xcode Command Line Tools are installed" "Y" -- bash -lc "
if xcode-select -p >/dev/null 2>&1; then
    echo 'Xcode Command Line Tools already installed.'
else
    echo 'Invoking xcode-select --install (may open GUI prompt)...'
    xcode-select --install || echo 'xcode-select --install returned non-zero status (expected if a GUI prompt appears).'
fi
"
    run_step "$section" "homebrew_bootstrap" "Ensure Homebrew is installed" "Y" -- bash -lc "
if command -v brew >/dev/null 2>&1; then
    echo 'Homebrew already installed at:' \"\$(command -v brew)\"
else
    echo 'Homebrew not found; running official installer...'
    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" || echo 'Homebrew installer exited with non-zero status.'
fi
"
    run_step "$section" "rosetta_check" "Install Rosetta 2 on Apple Silicon (if needed)" "N" -- bash -lc "
if [[ \$(uname -m) == 'arm64' ]]; then
    if /usr/sbin/softwareupdate --history | grep -q 'Rosetta'; then
        echo 'Rosetta already installed.'
    else
        echo 'Installing Rosetta (requires admin privileges)...'
        sudo softwareupdate --install-rosetta --agree-to-license || echo 'Rosetta installation command failed.'
    fi
else
    echo 'Not running on Apple Silicon; Rosetta not required.'
fi
"
}

run_install_phase() {
    log_master "--- Phase: Installation ---"
    local section="install_logs"
    run_step "$section" "preflight" "Run repository preflight (permissions/quarantine reset)" "Y" \
        -- "$ADS_ROOT/preflight.sh"
    run_step "$section" "install_standard" "Execute install.sh --standard (requires sudo)" "Y" \
        -- sudo "$ADS_ROOT/install.sh" --standard
}

run_round1_validation() {
    log_master "--- Phase: Round 1 Validation ---"
    local section="round_1_validation"
    run_step "$section" "orchestrator_dry_run" "Core orchestrator dry run (--mode standard)" "Y" \
        -- "$ADS_ROOT/core/00-automatic-dev-orchestrator.sh" --dry-run --mode standard
    run_step "$section" "validate_standard" "Validation suite --mode standard" "Y" \
        -- "$ADS_ROOT/operations_support/09-automatic-dev-validate.sh" --mode standard
    run_step "$section" "validate_dry_run" "Validation suite --dry-run (if supported)" "N" \
        -- "$ADS_ROOT/operations_support/09-automatic-dev-validate.sh" --dry-run
    run_step "$section" "tail_failure_events" "Tail failure-events.jsonl" "Y" \
        -- bash -lc "tail -n 50 ~/.automatic_dev_setup/logs/failure-events.jsonl"
    run_step "$section" "tail_failure_codes" "Tail failure-codes.log" "Y" \
        -- bash -lc "tail -n 50 ~/.automatic_dev_setup/logs/failure-codes.log"
    run_step "$section" "brew_doctor" "brew doctor" "N" \
        --workdir "$HOME" -- bash -lc "brew doctor"
    run_step "$section" "brew_missing" "brew missing" "N" \
        --workdir "$HOME" -- bash -lc "brew missing"
    run_step "$section" "brew_bundle_check" "brew bundle check for ADS Brewfile" "N" \
        --workdir "$HOME" -- bash -lc "brew bundle check --file '$ADS_ROOT/config/Brewfile.automatic-dev'"
    run_step "$section" "pip_check" "pip check inside ADS venv" "N" \
        -- bash -lc "source ~/coding_environment/.venvs/automatic-dev/bin/activate && pip check && deactivate"
    run_step "$section" "container_suite_verify" "Container suite verify" "Y" \
        -- "$ADS_ROOT/tools/automatic-dev-container-suite.sh" verify
    run_step "$section" "launchctl_status" "launchctl list | grep automatic-dev" "Y" \
        -- bash -lc "launchctl list | grep automatic-dev"
}

run_round2_troubleshooting() {
    log_master "--- Phase: Round 2 Troubleshooting ---"
    local section="round_2_troubleshooting"
    run_step "$section" "copy_failure_catalog" "Copy failure-catalog.tsv" "Y" \
        -- bash -lc "cp '$ADS_ROOT/config/failure-catalog.tsv' '${RUN_ROOT}/${section}/failure-catalog.tsv'"
    run_step "$section" "copy_troubleshooting_doc" "Copy TROUBLESHOOTING.md" "Y" \
        -- bash -lc "cp '$ADS_ROOT/docs/TROUBLESHOOTING.md' '${RUN_ROOT}/${section}/TROUBLESHOOTING.md'"
    run_step "$section" "troubleshooting_dry_run_M01" "Troubleshooting dry-run ADS-M01" "N" \
        -- bash -lc "echo 'ADS-M01' | '$ADS_ROOT/troubleshooting.sh'"
    run_step "$section" "troubleshooting_dry_run_M02" "Troubleshooting dry-run ADS-M02" "N" \
        -- bash -lc "echo 'ADS-M02' | '$ADS_ROOT/troubleshooting.sh'"
}

run_round3_snapshot() {
    log_master "--- Phase: Round 3 Analysis Snapshot ---"
    local section="round_3_analysis_snapshot"
    run_step "$section" "snapshot_repository" "Snapshot repository for offline review" "Y" \
        -- bash -lc "
dest='${RUN_ROOT}/${section}/repository_snapshot'
mkdir -p \"\$dest\"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude '.git/' --exclude 'special_files/special_logs/' ./ \"\$dest/\"
else
    cp -R . \"\$dest\"
fi
"
    run_step "$section" "file_tree" "Capture repository file tree" "Y" \
        -- bash -lc "find '$ADS_ROOT' -type f"
}

run_round4_conformance() {
    log_master "--- Phase: Round 4 Conformance Reports ---"
    local section="round_4_conformance_reports"
    run_step "$section" "shellcheck_suite" "Shellcheck all suite scripts" "Y" \
        -- bash -lc "
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning -a '$ADS_ROOT'/*.sh '$ADS_ROOT'/core/*.sh '$ADS_ROOT'/lib/*.sh '$ADS_ROOT'/operations_setup/*.sh '$ADS_ROOT'/operations_support/*.sh '$ADS_ROOT'/tools/*.sh
else
    echo 'shellcheck not installed.'
fi
"
    run_step "$section" "complexity_scan" "Rudimentary complexity scan (count conditionals)" "Y" \
        -- bash -lc "grep -E 'if |for |while |case ' '$ADS_ROOT'/lib/*.sh '$ADS_ROOT'/core/*.sh | wc -l"
    run_step "$section" "large_function_scan" "Detect large shell functions (>100 lines)" "Y" \
        -- bash -lc "
awk '
    /^[_[:alnum:]]+\\s*\\(\\)\\s*\\{/ { fn=\$1; line=NR }
    /^\\}/ && fn { if (NR-line > 100) { printf(\"%s %d\\n\", fn, NR-line) } fn=\"\" }
' '$ADS_ROOT'/lib/*.sh '$ADS_ROOT'/core/*.sh
"
}

run_resource_snapshot() {
    log_master "--- Phase: Resource Snapshot ---"
    run_step "system_state" "resource_usage" "Capture CPU/memory snapshot" "Y" \
        --workdir "$HOME" -- bash -lc "
if command -v top >/dev/null 2>&1; then
    top -l 1
fi
if command -v vm_stat >/dev/null 2>&1; then
    vm_stat
fi
"
}

main() {
    if [[ -z "$CUSTOM_LOG_ROOT" ]]; then
        mkdir -p "$DEFAULT_BASE"
    fi

    log_master "=== STARTING SPECIAL AUDIT RUN ==="
    log_master "Project Root: $ADS_ROOT"
    log_master "Log Root: $RUN_ROOT"

    log_system_state
    validate_telemetry_targets
    run_preinstall_checks
    run_install_phase
    run_round1_validation
    run_round2_troubleshooting
    run_round3_snapshot
    run_round4_conformance
    run_resource_snapshot

    finalize_run
    log_master "=== AUDIT RUN COMPLETE ==="
}

main "$@"
