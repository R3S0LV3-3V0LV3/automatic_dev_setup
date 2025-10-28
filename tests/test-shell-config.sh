#!/usr/bin/env bash
# =============================================================================
# test-shell-config.sh - Test shell configuration structure
# Purpose: Validate that shell configuration files follow the expected structure
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
    ((TESTS_RUN++))
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test function to check file sections
check_section() {
    local file="$1"
    local section="$2"
    
    if grep -q "$section" "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Test .zshrc structure
test_zshrc() {
    local file="$HOME/.zshrc"
    log_test "Testing .zshrc structure"
    
    if [[ ! -f "$file" ]]; then
        log_fail ".zshrc does not exist"
        return 1
    fi
    
    local sections=(
        "Core Shell Settings"
        "Homebrew Environment"
        "Shell Completions"
        "Environment variables"
        "Modern CLI aliases"
        "Git workflow aliases"
        "Docker aliases"
        "Utility functions"
    )
    
    for section in "${sections[@]}"; do
        if check_section "$file" "$section"; then
            log_pass "Found section: $section"
        else
            log_fail "Missing section: $section"
        fi
    done
}

# Test .zprofile structure
test_zprofile() {
    local file="$HOME/.zprofile"
    log_test "Testing .zprofile structure"
    
    if [[ ! -f "$file" ]]; then
        log_fail ".zprofile does not exist"
        return 1
    fi
    
    local sections=(
        "Core Environment"
        "Homebrew Environment"
        "Development Tool Paths"
        "User-specific Paths"
        "System Architecture Flags"
        "Security and Privacy Settings"
    )
    
    for section in "${sections[@]}"; do
        if check_section "$file" "$section"; then
            log_pass "Found section: $section"
        else
            log_fail "Missing section: $section"
        fi
    done
}

# Test .profile structure
test_profile() {
    local file="$HOME/.profile"
    log_test "Testing .profile structure"
    
    if [[ ! -f "$file" ]]; then
        log_fail ".profile does not exist"
        return 1
    fi
    
    local sections=(
        "Core Environment Variables"
        "Default Programs"
        "XDG Base Directory"
        "Development Environments"
        "User Paths"
        "Development Settings"
        "System Settings"
    )
    
    for section in "${sections[@]}"; do
        if check_section "$file" "$section"; then
            log_pass "Found section: $section"
        else
            log_fail "Missing section: $section"
        fi
    done
}

# Test PATH integrity
test_path_integrity() {
    log_test "Testing PATH integrity"
    
    # Check for duplicates
    local duplicates
    duplicates=$(echo "$PATH" | tr ':' '\n' | sort | uniq -d)
    
    if [[ -z "$duplicates" ]]; then
        log_pass "No duplicate PATH entries"
    else
        log_fail "Found duplicate PATH entries: $duplicates"
    fi
    
    # Check for key paths
    local key_paths=(
        "/opt/homebrew/bin"
        "$HOME/.local/bin"
        "$HOME/automatic_dev_setup/bin"
    )
    
    for path in "${key_paths[@]}"; do
        if echo "$PATH" | grep -q "$path"; then
            log_pass "PATH contains: $path"
        else
            log_fail "PATH missing: $path"
        fi
    done
}

# Test environment variables
test_environment_vars() {
    log_test "Testing environment variables"
    
    local vars=(
        "AUTOMATIC_DEV_HOME"
        "CODE_DIR"
        "PROJECTS_DIR"
        "PYENV_ROOT"
        "GOPATH"
        "GEM_HOME"
        "NVM_DIR"
    )
    
    for var in "${vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_pass "$var is set: ${!var}"
        else
            log_fail "$var is not set"
        fi
    done
}

# Run dry-run mode if requested
if [[ "${1:-}" == "--dry-run" ]]; then
    echo "=== DRY RUN MODE ==="
    echo "Would test the following:"
    echo "- .zshrc structure and sections"
    echo "- .zprofile structure and sections"
    echo "- .profile structure and sections"
    echo "- PATH integrity (duplicates and required paths)"
    echo "- Environment variables"
    exit 0
fi

# Main test execution
echo "=== Shell Configuration Test Suite ==="
echo "Testing shell configuration files..."
echo

test_zshrc
echo

test_zprofile
echo

test_profile
echo

test_path_integrity
echo

test_environment_vars
echo

# Summary
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi