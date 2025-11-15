#!/usr/bin/env bash
# =============================================================================
# troubleshooting.sh — Automatic Dev Setup Recovery
# Author: Kieran Tandi
# Purpose: When things go wrong — and they will — this sorts them out
# Version: 3.0.0
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/automatic-dev-config.env"
source "$REPO_ROOT/lib/automatic-dev-diagnostics.sh"

LOG_ROOT="${ADS_LOG_ROOT:-$HOME/.automatic_dev_setup/logs}"
FAILURE_LOG="${ADS_FAILURE_LOG:-$LOG_ROOT/failure-codes.log}"
ORCHESTRATOR_INSTALL="$ADS_INSTALL_ROOT/core/00-automatic-dev-orchestrator.sh"
ORCHESTRATOR_LOCAL="$REPO_ROOT/core/00-automatic-dev-orchestrator.sh"
if [[ -x "$ORCHESTRATOR_LOCAL" ]]; then
    ORCHESTRATOR="$ORCHESTRATOR_LOCAL"
else
    ORCHESTRATOR="$ORCHESTRATOR_INSTALL"
fi

mkdir -p "$LOG_ROOT"

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local reply
    read -r -p "$prompt [${default}/$( [[ $default == Y ]] && echo N || echo Y )]: " reply
    reply=${reply:-$default}
    [[ "${reply^^}" == "Y" ]]
}

ensure_sudo() {
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    echo "Requesting sudo access..."
    sudo -v
}

run_module() {
    local module="$1"
    if [[ ! -x "$ORCHESTRATOR" ]]; then
        echo "Unable to locate orchestrator at $ORCHESTRATOR"
        return 1
    fi
    "$ORCHESTRATOR" --mode "${ADS_MODE:-standard}" --only "$module"
}

handle_ads_m01() {
    echo "[ADS-M01] System bootstrap remediation"
    if prompt_yes_no "Re-run module 01 (system bootstrap)?" Y; then
        run_module "01-system-bootstrap"
    fi
}

handle_ads_m02() {
    echo "[ADS-M02] Homebrew foundation remediation"
    if prompt_yes_no "Run xcode-select --install (may prompt via GUI)?" N; then
        xcode-select --install || true
        echo "If a GUI prompt appears, complete the installation before continuing."
    fi
    if prompt_yes_no "Run brew doctor?" Y; then
        brew doctor || true
    fi
    if prompt_yes_no "Run brew update && brew upgrade?" Y; then
        brew update || true
        brew upgrade || true
    fi
    if prompt_yes_no "Apply Brewfile bundle again?" Y; then
        if [[ -f "$ADS_BREWFILE" ]]; then
            brew bundle --file="$ADS_BREWFILE" || true
        else
            echo "Brewfile not found at $ADS_BREWFILE"
        fi
    fi
    if prompt_yes_no "Re-run module 02 (Homebrew foundation)?" Y; then
        run_module "02-homebrew-foundation"
    fi
}

handle_ads_m03() {
    echo "[ADS-M03] Shell environment remediation"
    if prompt_yes_no "Re-run module 03 (shell environment)?" Y; then
        run_module "03-shell-environment"
    fi
}

handle_ads_m04() {
    echo "[ADS-M04] Python ecosystem remediation"
    if prompt_yes_no "Remove and recreate the managed virtual environment?" N; then
        rm -rf "$ADS_VENV_DEFAULT"
        run_module "04-python-ecosystem"
        return
    fi
    if prompt_yes_no "Reinstall Python requirements inside venv?" Y; then
        if [[ -f "$ADS_VENV_DEFAULT/bin/activate" ]]; then
            # shellcheck disable=SC1090
            source "$ADS_VENV_DEFAULT/bin/activate"
            pip install --upgrade pip setuptools wheel || true
            if [[ -f "$ADS_REQUIREMENTS_FILE" && -f "$ADS_CONSTRAINTS_FILE" ]]; then
                pip install --requirement "$ADS_REQUIREMENTS_FILE" --constraint "$ADS_CONSTRAINTS_FILE" || true
            fi
            deactivate
        else
            echo "Virtual environment missing at $ADS_VENV_DEFAULT"
        fi
    fi
    if prompt_yes_no "Re-run module 04 (python ecosystem)?" Y; then
        run_module "04-python-ecosystem"
    fi
}

handle_ads_m05() {
    echo "[ADS-M05] Development stack remediation"
    if prompt_yes_no "Re-run module 05 (development stack)?" Y; then
        run_module "05-development-stack"
    fi
}

handle_ads_m06() {
    echo "[ADS-M06] Database systems remediation"
    if prompt_yes_no "Restart PostgreSQL, Redis, and MongoDB services?" Y; then
        ensure_sudo
        brew services restart postgresql@16 || true
        brew services restart redis || true
        brew services restart mongodb-community@7.0 || true
    fi
    if prompt_yes_no "Re-run module 06 (database systems)?" Y; then
        run_module "06-database-systems"
    fi
}

handle_ads_m07() {
    echo "[ADS-M07] Project template remediation"
    if prompt_yes_no "Resynchronise templates now?" Y; then
        run_module "07-project-templates"
    fi
}

handle_ads_m08() {
    echo "[ADS-M08] System optimisation remediation"
    if prompt_yes_no "Run brew cleanup and autoremove?" Y; then
        brew cleanup -s || true
        brew autoremove || true
    fi
    if prompt_yes_no "Reapply power management defaults (mode: ${ADS_MODE:-standard})?" Y; then
        ensure_sudo
        if [[ "${ADS_MODE:-standard}" == "performance" ]]; then
            sudo pmset -a displaysleep 0 disksleep 0 powernap 0 autopoweroff 0 standby 0 || true
        else
            sudo pmset -a displaysleep 15 disksleep 10 powernap 0 || true
        fi
    fi
    if prompt_yes_no "Re-run module 08 (system optimisation)?" Y; then
        run_module "08-system-optimisation"
    fi
}

handle_ads_m09() {
    echo "[ADS-M09] Validation remediation"
    if prompt_yes_no "Reinstall core ML packages (TensorFlow/PyTorch) inside venv?" N; then
        if [[ -f "$ADS_VENV_DEFAULT/bin/activate" ]]; then
            # shellcheck disable=SC1090
            source "$ADS_VENV_DEFAULT/bin/activate"
            pip install --force-reinstall tensorflow-macos==2.16.2 tensorflow-metal==1.1.0 torch==2.9.0 torchvision torchaudio || true
            deactivate
        else
            echo "Virtual environment missing at $ADS_VENV_DEFAULT"
        fi
    fi
    if prompt_yes_no "Re-run validation suite now?" Y; then
        local validate_path
        if [[ -x "$REPO_ROOT/operations_support/09-automatic-dev-validate.sh" ]]; then
            validate_path="$REPO_ROOT/operations_support/09-automatic-dev-validate.sh"
        else
            validate_path="$ADS_INSTALL_ROOT/operations_support/09-automatic-dev-validate.sh"
        fi
        "$validate_path" --mode "${ADS_MODE:-standard}" || true
    fi
}

handle_ads_m10() {
    echo "[ADS-M10] Maintenance job remediation"
    if prompt_yes_no "Reload maintenance launchd job?" Y; then
        ensure_sudo
        launchctl unload "$ADS_MAINTENANCE_ROOT/com.automatic-dev.maintenance.plist" 2>/dev/null || true
        launchctl load -w "$ADS_MAINTENANCE_ROOT/com.automatic-dev.maintenance.plist" || true
    fi
}

handle_code() {
    local code="$1"
    describe_code "$code"
    case "$code" in
        ADS-M01) handle_ads_m01 ;;
        ADS-M02) handle_ads_m02 ;;
        ADS-M03) handle_ads_m03 ;;
        ADS-M04) handle_ads_m04 ;;
        ADS-M05) handle_ads_m05 ;;
        ADS-M06) handle_ads_m06 ;;
        ADS-M07) handle_ads_m07 ;;
        ADS-M08) handle_ads_m08 ;;
        ADS-M09) handle_ads_m09 ;;
        ADS-M10) handle_ads_m10 ;;
        *)
            echo "No automated playbook for code $code. Consult docs/TROUBLESHOOTING.md."
            ;;
    esac
}

collect_failure_codes() {
    if [[ ! -f "$FAILURE_LOG" ]]; then
        return
    fi
    awk -F $'\t' '{print $3}' "$FAILURE_LOG" | tail -n 20 | tac | awk '!seen[$1]++ {print $1}'
}

describe_code() {
    local code="$1"
    local summary_line
    summary_line=$(ads_failure_summary_line "$code" 2>/dev/null || true)
    if [[ -n "$summary_line" ]]; then
        echo "----------------------------------------"
        echo "$summary_line"
        local doc_ref
        doc_ref=$(ads_failure_doc_reference "$code" 2>/dev/null || echo "")
        if [[ -n "$doc_ref" ]]; then
            echo "Knowledge base: $doc_ref"
        fi
        local recent_context
        recent_context=$(collect_recent_context "$code")
        if [[ -n "$recent_context" ]]; then
            echo "Most recent failing command: $recent_context"
        fi
    else
        echo "----------------------------------------"
        echo "No metadata available for $code. Consult ${ADS_TROUBLESHOOTING:-docs/TROUBLESHOOTING.md}."
    fi
}

collect_recent_context() {
    local code="$1"
    [[ -f "$FAILURE_LOG" ]] || return 0
    awk -F $'\t' -v target="$code" '$3 == target {ctx=$NF} END {if (ctx) print ctx}' "$FAILURE_LOG"
}

main() {
    codes=()
    while IFS= read -r line; do
        codes=("${codes[@]}" "$line")
    done < <(collect_failure_codes)
    if [[ ${#codes[@]} -eq 0 ]]; then
        echo "No recorded failure codes found at $FAILURE_LOG."
        read -r -p "Enter a failure code manually (or press Enter to exit): " manual_code
        if [[ -z "$manual_code" ]]; then
            exit 0
        fi
        codes=("$manual_code")
    fi

    echo "Detected failure codes: ${codes[*]}"
    for code in "${codes[@]}"; do
        if prompt_yes_no "Attempt automated remediation for $code?" Y; then
            handle_code "$code"
        else
            echo "Skipping $code."
        fi
    done

    if prompt_yes_no "Would you like to rerun the full orchestrator now?" N; then
        "$ORCHESTRATOR" --mode "${ADS_MODE:-standard}"
    fi

    echo "Troubleshooting session complete. Review $FAILURE_LOG for history."
}

main "$@"
