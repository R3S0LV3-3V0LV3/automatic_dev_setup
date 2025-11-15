#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export ADS_RUNTIME_DIR="$(mktemp -d /tmp/ads-runtime-tests.XXXXXX)"
export ADS_BACKUP_DIR="$(mktemp -d /tmp/ads-backup-tests.XXXXXX)"

# shellcheck source=automatic-dev-suite/lib/automatic-dev-core.sh
source "$SUITE_ROOT/lib/automatic-dev-core.sh"

PASS=0
FAIL=0

cleanup() {
    rm -rf "$ADS_RUNTIME_DIR" "$ADS_BACKUP_DIR"
}
trap cleanup EXIT

run_test() {
    local name="$1"
    shift
    if "$@"; then
        printf '[PASS] %s\n' "$name"
        ((PASS++)) || true
    else
        local status=$?
        printf '[FAIL] %s (exit %s)\n' "$name" "$status"
        ((FAIL++)) || true
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    [[ "$expected" == "$actual" ]]
}

ads_append_once_idempotent() {
    local tmp
    tmp=$(mktemp)
    ads_append_once "alpha" "$tmp"
    ads_append_once "alpha" "$tmp"
    local count
    count=$(grep -c '^alpha$' "$tmp")
    rm -f "$tmp"
    assert_equals "1" "$count"
}

ads_append_once_property() {
    local tmp
    tmp=$(mktemp)
    for _ in {1..5}; do
        local token
        token=$(openssl rand -hex 4)
        ads_append_once "$token" "$tmp"
        ads_append_once "$token" "$tmp"
        local count
        count=$(grep -c "^${token}$" "$tmp")
        if [[ "$count" -ne 1 ]]; then
            rm -f "$tmp"
            return 1
        fi
    done
    rm -f "$tmp"
    return 0
}

ads_ensure_directory_creates() {
    local dir
    dir=$(mktemp -d)
    rm -rf "$dir"
    ads_ensure_directory "$dir"
    [[ -d "$dir" ]]
}

ads_clear_quarantine_requires_param() {
    if ads_clear_quarantine >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

ads_verify_checksum_success() {
    local tmp
    tmp=$(mktemp)
    printf 'hello' > "$tmp"
    local expected="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    ads_verify_checksum "$tmp" "$expected"
    rm -f "$tmp"
}

ads_verify_checksum_failure() {
    local tmp
    tmp=$(mktemp)
    printf 'hello' > "$tmp"
    if ads_verify_checksum "$tmp" "deadbeef" >/dev/null 2>&1; then
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    return 0
}

ads_module_progress_tracks() {
    local file
    file=$(ads_module_progress_file)
    > "$file"
    ads_record_module_event "01-system-bootstrap" "SUCCESS"
    ads_record_module_event "02-homebrew-foundation" "SUCCESS"
    local last
    last=$(ads_last_successful_module)
    assert_equals "02-homebrew-foundation" "$last"
}

run_test "ads_append_once_idempotent" ads_append_once_idempotent
run_test "ads_append_once_property" ads_append_once_property
run_test "ads_ensure_directory_creates" ads_ensure_directory_creates
run_test "ads_clear_quarantine_requires_param" ads_clear_quarantine_requires_param
run_test "ads_verify_checksum_success" ads_verify_checksum_success
run_test "ads_verify_checksum_failure" ads_verify_checksum_failure
run_test "ads_module_progress_tracks" ads_module_progress_tracks

if (( FAIL > 0 )); then
    exit 1
fi
