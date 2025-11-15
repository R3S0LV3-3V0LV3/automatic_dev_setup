#!/usr/bin/env bash
# =============================================================================
# 09-integration-validation.sh - Automatic Dev Setup
# Purpose: Execute comprehensive validation suite covering system, runtime, and services.
# Version: 3.0.0
# Dependencies: bash, python, brew
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"
source "$ADS_TEST_SUITE"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M09}"

main() {
    log_header "[09] Integration Validation"
    TEST_START_TIME=$(date +%s)

    #test_macos_version
    #test_architecture
    #test_system_resources
    #test_homebrew_installation
    #test_homebrew_health
    #test_homebrew_packages
    #test_python_installation
    #test_virtual_environment
    #test_pip_check
    #test_tensorflow
    #test_pytorch
    #test_postgresql
    #test_redis
    #test_mongodb
    #test_docker_cli
    #test_kubernetes_cli
    #test_editor_stack
    #test_shell_startup_time
    test_python_suite
    test_unit_suite
    test_version_locks

    generate_test_report
    local result=$?
    if (( result == 0 )); then
        log_success "Validation suite completed with zero failures."
        exit 0
    else
        log_error "Validation suite completed with failures."
        exit $result
    fi
}

main "$@"
