#!/usr/bin/env bash
# =============================================================================
# automatic-dev-tests.sh - Automatic Dev Setup
# Purpose: Provide comprehensive validation functions for environment auditing.
# Version: 3.0.0
# Dependencies: bash, python, brew, git
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=automatic-dev-suite/lib/automatic-dev-core.sh
. "$SUITE_ROOT/lib/automatic-dev-core.sh"
. "$SUITE_ROOT/automatic-dev-config.env"
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M09}"

test_passed=0
test_failed=0
test_warnings=0
TEST_RESULTS=()
TEST_START_TIME=0

tfcheck() {
python - <<'PYEOF'
import sys
try:
    import tensorflow as tf
    devices = tf.config.list_physical_devices()
    result = tf.reduce_sum(tf.constant([1.0, 2.0, 3.0])).numpy()
    if result != 6.0:
        raise RuntimeError(f"Unexpected TensorFlow sum result: {result}")
    target = '/GPU:0' if tf.config.list_physical_devices('GPU') else '/CPU:0'
    with tf.device(target):
        tf.constant([0.0])
except Exception as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PYEOF
}

torchcheck() {
python - <<'PYEOF'
import sys
try:
    import torch
    target = 'mps' if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available() else 'cpu'
    tensor = torch.tensor([1.0, 2.0, 3.0], device=target)
    result = torch.sum(tensor).item()
    if result != 6.0:
        raise RuntimeError(f"Unexpected PyTorch sum result: {result}")
except Exception as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PYEOF
}

activate_ads_venv() {
    echo "DEBUG: Attempting to activate venv: $ADS_VENV_DEFAULT/bin/activate"
    if [[ -f "$ADS_VENV_DEFAULT/bin/activate" ]]; then
        # shellcheck disable=SC1090
        source "$ADS_VENV_DEFAULT/bin/activate"
        echo "DEBUG: Venv activated."
        return 0
    fi
    echo "DEBUG: Venv activation failed."
    return 1
}

deactivate_ads_venv() {
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        deactivate
    fi
}

test_pass() {
    local test_name="$1"
    ((test_passed++)) || true
    TEST_RESULTS+=("PASS: $test_name")
    log_success "✅ $test_name"
}

test_fail() {
    local test_name="$1"
    local error_msg="${2:-No error message provided}"
    ((test_failed++)) || true
    TEST_RESULTS+=("FAIL: $test_name - $error_msg")
    log_error "❌ $test_name - $error_msg"
}

test_warning() {
    local test_name="$1"
    local warning_msg="${2:-No warning message provided}"
    ((test_warnings++)) || true
    TEST_RESULTS+=("WARN: $test_name - $warning_msg")
    log_warning "⚠️ $test_name - $warning_msg"
}

test_macos_version() {
    local macos_version
    macos_version=$(sw_vers -productVersion 2>/dev/null)
    if [[ -n "$macos_version" ]]; then
        local major="${macos_version%%.*}"
        if (( major >= 12 )); then
            test_pass "macOS version check: $macos_version"
        else
            test_warning "macOS version check: $macos_version (<12)"
        fi
    else
        test_fail "macOS version check" "Unable to detect version"
    fi
}

test_architecture() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        arm64)
            test_pass "Architecture: arm64 (Apple Silicon)"
            ;;
        x86_64)
            test_warning "Architecture: x86_64 (supported, not optimal)"
            ;;
        *)
            test_fail "Architecture check" "Unsupported architecture: $arch"
            ;;
    esac
}

test_system_resources() {
    local memory_gb
    memory_gb=$(sysctl -n hw.memsize | awk '{print int($0/1024/1024/1024)}')
    if (( memory_gb >= 16 )); then
        test_pass "System memory: ${memory_gb}GB"
    elif (( memory_gb >= 8 )); then
        test_warning "System memory: ${memory_gb}GB (minimum threshold)"
    else
        test_fail "System memory" "${memory_gb}GB detected (<8GB)"
    fi

    local available_gb
    available_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')
    if (( available_gb >= 50 )); then
        test_pass "Disk space: ${available_gb}GB free"
    elif (( available_gb >= 20 )); then
        test_warning "Disk space: ${available_gb}GB (minimum threshold)"
    else
        test_fail "Disk space" "${available_gb}GB (<20GB)"
    fi
}

test_homebrew_installation() {
    if command -v brew >/dev/null 2>&1; then
        local brew_version
        brew_version=$(brew --version | head -1 | awk '{print $2}')
        test_pass "Homebrew: $brew_version"
    else
        test_fail "Homebrew installation" "brew not found"
    fi
}

test_homebrew_health() {
    if brew doctor >/dev/null 2>&1; then
        test_pass "brew doctor"
    else
        test_warning "brew doctor" "Reported issues"
    fi
}

test_homebrew_packages() {
    local required_packages=(
        git gh python@3.11 node@20 postgresql@16 redis mongodb-community@7.0
        eza bat ripgrep fd fzf jq tmux neovim kubectl helm k9s kind colima docker
    )
    if [[ "${ADS_MODE:-standard}" == "performance" ]]; then
        required_packages+=(
            hyperfine bandwhich glances wrk siege hey tokei
            istat-menus bettertouchtool karabiner-elements
        )
    fi
    local missing=()
    for pkg in "${required_packages[@]}"; do
        if brew list "$pkg" >/dev/null 2>&1 || brew list --cask "$pkg" >/dev/null 2>&1; then
            test_pass "Package installed: $pkg"
        else
            missing+=("$pkg")
            test_fail "Package missing" "$pkg"
        fi
    done
    if (( ${#missing[@]} )); then
        log_warning "Missing packages: ${missing[*]}"
    fi
}

test_python_installation() {
    if command -v python3 >/dev/null 2>&1; then
        test_pass "python3 availability"
    else
        test_fail "python3 installation" "python3 not found"
    fi
}

test_virtual_environment() {
    local venv_path="$ADS_VENV_DEFAULT"
    if [[ -d "$venv_path" && -f "$venv_path/bin/activate" ]]; then
        test_pass "Automatic Dev venv present"
        if activate_ads_venv; then
            test_python_packages
            deactivate_ads_venv
        else
            test_fail "Automatic Dev venv activation" "Unable to activate $venv_path"
        fi
    else
        test_fail "Automatic Dev venv" "Missing at $venv_path"
    fi
}

test_python_packages() {
    local packages=(numpy pandas matplotlib seaborn sklearn jupyter tensorflow torch fastapi streamlit gradio)
    for package in "${packages[@]}"; do
        if python -c "import ${package}" >/dev/null 2>&1; then
            test_pass "Python package: $package"
        else
            test_fail "Python package" "$package not importable"
        fi
    done
}

test_pip_check() {
    if activate_ads_venv; then
        if pip check >/dev/null 2>&1; then
            test_pass "pip check"
        else
            local conflicts
            conflicts=$(pip check)
            test_fail "pip check" "$conflicts"
        fi
        deactivate_ads_venv
    else
        test_fail "pip check" "Unable to activate Automatic Dev venv"
    fi
}

test_tensorflow() {
    if activate_ads_venv; then
        if tfcheck >/dev/null 2>&1; then
            test_pass "TensorFlow validation"
        else
            test_fail "TensorFlow validation" "tfcheck failed"
        fi
        deactivate_ads_venv
    else
        test_fail "TensorFlow validation" "Unable to activate Automatic Dev venv"
    fi
}

test_pytorch() {
    if activate_ads_venv; then
        if torchcheck >/dev/null 2>&1; then
            test_pass "PyTorch validation"
        else
            test_fail "PyTorch validation" "torchcheck failed"
        fi
        deactivate_ads_venv
    else
        test_fail "PyTorch validation" "Unable to activate Automatic Dev venv"
    fi
}

test_postgresql() {
    if command -v psql >/dev/null 2>&1; then
        if brew services list | grep -q "postgresql@16 .* started"; then
            test_pass "PostgreSQL service running"
            if psql -d postgres -c "SELECT version();" >/dev/null 2>&1; then
                test_pass "PostgreSQL connection"
            else
                test_fail "PostgreSQL connection" "Unable to run query"
            fi
        else
            test_warning "PostgreSQL service" "Not running"
        fi
    else
        test_fail "PostgreSQL client" "psql not found"
    fi
}

test_redis() {
    if command -v redis-cli >/dev/null 2>&1; then
        if brew services list | grep -q "redis .* started"; then
            if redis-cli ping | grep -q PONG; then
                test_pass "Redis ping"
            else
                test_fail "Redis ping" "No PONG response"
            fi
        else
            test_warning "Redis service" "Not running"
        fi
    else
        test_fail "Redis client" "redis-cli not found"
    fi
}

test_mongodb() {
    if command -v mongosh >/dev/null 2>&1; then
        if brew services list | grep -q "mongodb-community@7.0 .* started"; then
            if mongosh --eval "db.runCommand({connectionStatus:1})" >/dev/null 2>&1; then
                test_pass "MongoDB connection"
            else
                test_fail "MongoDB connection" "Connection failed"
            fi
        else
            test_warning "MongoDB service" "Not running"
        fi
    else
        test_fail "MongoDB client" "mongosh not found"
    fi
}

test_docker_cli() {
    if command -v docker >/dev/null 2>&1; then
        if docker --version >/dev/null 2>&1; then
            test_pass "Docker CLI available"
        else
            test_warning "Docker CLI" "Docker installed but daemon may be offline"
        fi
    else
        test_warning "Docker CLI" "Docker not found (launch Docker.app to finish installation)"
    fi

    if command -v colima >/dev/null 2>&1; then
        if colima version >/dev/null 2>&1; then
            test_pass "Colima CLI available"
        else
            test_warning "Colima CLI" "Colima present but returned non-zero status"
        fi
    else
        test_warning "Colima CLI" "Colima not detected"
    fi
}

test_kubernetes_cli() {
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl version --client >/dev/null 2>&1; then
            test_pass "kubectl client available"
        else
            test_warning "kubectl client" "kubectl returned non-zero status"
        fi
    else
        test_warning "kubectl" "kubectl not detected"
    fi

    if command -v helm >/dev/null 2>&1; then
        if helm version --short >/dev/null 2>&1; then
            test_pass "Helm client available"
        else
            test_warning "Helm client" "Helm returned non-zero status"
        fi
    else
        test_warning "Helm" "Helm not detected"
    fi

    if command -v k9s >/dev/null 2>&1; then
        k9s version >/dev/null 2>&1 || test_warning "k9s" "k9s present but returned non-zero status"
    fi
}

test_editor_stack() {
    if command -v nvim >/dev/null 2>&1; then
        test_pass "Neovim available"
    else
        test_warning "Neovim" "Neovim not detected"
    fi
}

test_shell_startup_time() {
    local duration
    duration=$(python3 - <<'PY'
import subprocess
import time

start = time.time()
subprocess.run(["zsh", "-i", "-c", "exit"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
end = time.time()
print(int((end - start) * 1000))
PY
)
    if (( duration < 2000 )); then
        test_pass "Shell startup ${duration}ms"
    else
        test_warning "Shell startup" "${duration}ms (>=2000)"
    fi
}

test_unit_suite() {
    local harness="$SUITE_ROOT/tests/unit/test_ads_core.sh"
    if [[ ! -x "$harness" ]]; then
        test_fail "ADS core unit tests" "Harness missing at $harness"
        return 1
    fi
    if "$harness"; then
        test_pass "ADS core unit tests"
    else
        test_fail "ADS core unit tests" "Unit harness reported failures"
    fi
}

test_version_locks() {
    local verifier="$SUITE_ROOT/tools/ads-verify-versions.sh"
    if [[ ! -x "$verifier" ]]; then
        test_fail "Version lock verification" "Verifier missing at $verifier"
        return 1
    fi
    if "$verifier"; then
        test_pass "Version lock verification"
    else
        test_fail "Version lock verification" "Mismatch detected; review logs"
    fi
}

test_python_suite() {
    if activate_ads_venv; then
        if ! command -v pytest >/dev/null 2>&1; then
            echo "DEBUG: Installing pytest"
            pip install pytest
            echo "DEBUG: pytest installed"
        fi
        echo "DEBUG: Running pytest"
        if pytest "$SUITE_ROOT/testing/test_suite.py"; then
            test_pass "Python test suite"
        else
            test_fail "Python test suite" "Pytest returned non-zero exit code"
        fi
        deactivate_ads_venv
    else
        test_fail "Python test suite" "Unable to activate Automatic Dev venv"
    fi
}

generate_test_report() {
    local report_file
    report_file="$ADS_LOG_ROOT/test-report-$(date +%Y%m%d-%H%M%S).md"
    ads_ensure_directory "$ADS_LOG_ROOT"
    echo "DEBUG: Creating report file: $report_file"
    local duration=$(( $(date +%s) - TEST_START_TIME ))
    cat > "$report_file" <<EOF
# Automatic Dev Setup - Test Report

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Duration: ${duration}s
System: $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))

## Summary
| Metric | Count |
|--------|-------|
| ✅ Passed | $test_passed |
| ❌ Failed | $test_failed |
| ⚠️ Warnings | $test_warnings |
| **Total** | $((test_passed + test_failed + test_warnings)) |

## Details
EOF
    for result in "${TEST_RESULTS[@]}"; do
        case "$result" in
            PASS:*) echo "- ✅ ${result#PASS: }" >> "$report_file" ;;
            FAIL:*) echo "- ❌ ${result#FAIL: }" >> "$report_file" ;;
            WARN:*) echo "- ⚠️ ${result#WARN: }" >> "$report_file" ;;
        esac
    done

    if (( test_failed > 0 )); then
        cat >> "$report_file" <<EOF

## Action Required
Review TROUBLESHOOTING.md for remediation guidance, then re-run failed modules.
EOF
    fi
    log_info "Test report saved to $report_file"
    return $test_failed
}
