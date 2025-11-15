#!/usr/bin/env bash
# =============================================================================
# automatic-dev-core.sh - Automatic Dev Setup
# Purpose: Provide reusable helper utilities for all Automatic Dev Setup scripts.
# Version: 3.0.0
# Dependencies: bash, mkdir, stat, command
# Criticality: ALPHA
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'automatic-dev-core.sh must be sourced, not executed directly.\n' >&2
    exit 1
fi

if [[ -n "${ADS_CORE_SH_LOADED:-}" ]]; then
    return 0
fi
ADS_CORE_SH_LOADED=1

set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck source=automatic-dev-suite/lib/automatic-dev-logging.sh
# shellcheck source=automatic-dev-suite/lib/automatic-dev-error-handling.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/automatic-dev-logging.sh"
source "$SCRIPT_DIR/automatic-dev-error-handling.sh"

ADS_MAX_RETRIES="${ADS_MAX_RETRIES:-3}"
ADS_RETRY_DELAY="${ADS_RETRY_DELAY:-5}"

ads_append_once() {
    local line="$1"
    local file="$2"
    [[ -z "$line" || -z "$file" ]] && { log_error "ads_append_once requires both a line and file path"; return 1; }
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if ! grep -Fqx "$line" "$file"; then
        printf '%s\n' "$line" >> "$file"
        log_debug "Appended line to $file: $line"
    fi
}

ads_ensure_directory() {
    local dir="$1"
    [[ -z "$dir" ]] && { log_error "ads_ensure_directory requires a directory path"; return 1; }
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

ads_require_command() {
    local cmd="$1"
    local package="${2:-}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [[ -n "$package" ]]; then
            log_error "Required command '$cmd' not found. Install: $package"
        else
            log_error "Required command '$cmd' not found."
        fi
        return 1
    fi
}

ads_retry() {
    local label="$1"
    shift
    local attempt=1
    local exit_code

    while (( attempt <= ADS_MAX_RETRIES )); do
        if "$@"; then
            log_success "$label succeeded on attempt $attempt"
            return 0
        fi
        exit_code=$?
        log_warning "$label failed on attempt $attempt (exit ${exit_code})"
        if (( attempt == ADS_MAX_RETRIES )); then
            log_error "$label exhausted retries"
            return "$exit_code"
        fi
        ((attempt++))
        sleep "$ADS_RETRY_DELAY"
    done
}

ads_run() {
    local label="$1"
    shift
    log_info "Executing: $label"
    "$@"
}

ads_clear_quarantine() {
    local target="${1:-}"
    [[ -z "$target" ]] && { log_error "ads_clear_quarantine requires a target path."; return 1; }

    log_info "Clearing Gatekeeper quarantine metadata for ${target}"
    if command -v xattr >/dev/null 2>&1; then
        xattr -dr com.apple.quarantine "$target" 2>/dev/null || log_debug "No quarantine attributes found on ${target}"
    else
        log_warning "xattr not available; skipping quarantine attribute removal."
    fi

    if command -v chmod >/dev/null 2>&1; then
        log_info "Normalising permissions under ${target}"
        chmod -RN "$target" 2>/dev/null || log_debug "chmod -RN reported issues; continuing."
    fi

    if command -v chflags >/dev/null 2>&1; then
        log_info "Resetting immutable flags under ${target}"
        if ! chflags -R nouchg,noschg "$target" 2>/dev/null; then
            if command -v sudo >/dev/null 2>&1; then
                log_warning "Retrying flag reset with sudo for ${target}"
                sudo chflags -R nouchg,noschg "$target" || log_warning "Unable to reset file flags for ${target}"
            else
                log_warning "chflags reset failed and sudo unavailable for ${target}"
            fi
        fi
    fi
}

ads_compute_sha256() {
    local file="$1"
    [[ -z "$file" ]] && { log_error "ads_compute_sha256 requires a file path."; return 1; }
    if [[ ! -f "$file" ]]; then
        log_error "ads_compute_sha256 cannot find file: $file"
        return 1
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
    else
        log_error "Unable to locate shasum, sha256sum, or openssl for checksum verification."
        return 1
    fi
}

ads_lookup_checksum_entry() {
    local artifact="$1"
    local catalog="${ADS_CHECKSUM_FILE:-}"
    [[ -z "$artifact" ]] && { log_error "ads_lookup_checksum_entry requires an artefact name."; return 1; }
    if [[ -z "$catalog" || ! -f "$catalog" ]]; then
        log_warning "Checksum catalogue missing at ${catalog:-<unset>}."
        return 1
    fi
    while IFS=$'\t' read -r name url checksum; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        if [[ "$name" == "$artifact" ]]; then
            printf '%s\t%s\n' "$url" "$checksum"
            return 0
        fi
    done < "$catalog"
    return 1
}

ads_verify_checksum() {
    local file="$1"
    local expected="$2"
    [[ -z "$file" || -z "$expected" ]] && { log_error "ads_verify_checksum requires a file path and expected digest."; return 1; }
    local actual
    if ! actual=$(ads_compute_sha256 "$file"); then
        return 1
    fi
    if [[ "$actual" != "$expected" ]]; then
        log_error "Checksum mismatch for ${file}. Expected ${expected}, observed ${actual}"
        return 1
    fi
    log_success "Checksum verified for ${file}"
}

ads_fetch_with_checksum() {
    local artifact="$1"
    local destination="$2"
    local override_url="${3:-}"
    local override_checksum="${4:-}"
    [[ -z "$artifact" || -z "$destination" ]] && { log_error "ads_fetch_with_checksum requires an artefact name and destination path."; return 1; }

    local metadata url checksum
    metadata=$(ads_lookup_checksum_entry "$artifact" 2>/dev/null || true)
    if [[ -z "$metadata" ]]; then
        if [[ -z "$override_url" || -z "$override_checksum" ]]; then
            log_error "No checksum metadata available for ${artifact}; provide explicit URL and checksum."
            return 1
        fi
        url="$override_url"
        checksum="$override_checksum"
    else
        url="${override_url:-${metadata%%$'\t'*}}"
        checksum="${override_checksum:-${metadata##*$'\t'}}"
    fi

    if [[ -z "$url" || -z "$checksum" ]]; then
        log_error "Incomplete metadata for ${artifact}; cannot proceed with download."
        return 1
    fi

    ads_ensure_directory "$(dirname "$destination")"
    log_info "Downloading ${artifact} from ${url}"
    if ! curl -fsSL "$url" -o "$destination"; then
        log_error "Failed to download ${artifact} from ${url}"
        return 1
    fi
    if ! ads_verify_checksum "$destination" "$checksum"; then
        rm -f "$destination"
        return 1
    fi
    return 0
}

ads_measure() {
    local label="$1"
    shift
    local start
    local end
    start=$(date +%s)
    "$@"
    local cmd_exit_code=$?
    if [[ $cmd_exit_code -eq 0 ]]; then
        end=$(date +%s)
        local duration
        duration=$((end - start))
        log_performance "$label" "$duration"
        return 0
    else
        return "$cmd_exit_code"
    fi
}

ads_require_sudo() {
    # Check if we already have valid sudo credentials
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    
    # Check if we're in a context where sudo shouldn't be needed
    if [[ "${ADS_NO_SUDO:-0}" == "1" ]]; then
        log_debug "Sudo requirement bypassed (ADS_NO_SUDO=1)"
        return 0
    fi
    
    # Only request if we actually need it
    log_info "Administrator privileges required for this operation"
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi
    
    # Refresh sudo timestamp to extend timeout
    sudo -v
}

ads_backup_file() {
    local file="$1"
    [[ -z "$file" ]] && { log_error "ads_backup_file requires a file path"; return 1; }
    if [[ -f "$file" ]]; then
        local backup
        backup="${file}.backup.$(date -u '+%Y%m%d%H%M%S')"
        cp "$file" "$backup"
        log_info "Backup created: $backup"
    fi
}

ads_detect_arch() {
    uname -m
}

ads_detect_macos_version() {
    sw_vers -productVersion 2>/dev/null || echo "UNKNOWN"
}

ads_require_arm64() {
    local arch
    arch=$(ads_detect_arch)
    if [[ "$arch" != "arm64" ]]; then
        log_warning "Architecture '$arch' detected. Apple Silicon (arm64) recommended."
    fi
}

ads_expand_path() {
    local raw_path="$1"
    [[ -z "$raw_path" ]] && { log_error "ads_expand_path requires a path."; return 1; }
    local expanded
    # shellcheck disable=SC2086
    expanded=$(eval "printf '%s' \"${raw_path}\"" 2>/dev/null) || return 1
    printf '%s' "$expanded"
}

ads_restore_manifest_entries() {
    local manifest="${ADS_RESTORE_MANIFEST:-}"
    if [[ -z "$manifest" || ! -f "$manifest" ]]; then
        log_warning "Restore manifest not found at ${manifest:-<unset>}."
        return 1
    fi
    while IFS= read -r entry; do
        [[ -z "$entry" || "$entry" =~ ^# ]] && continue
        printf '%s\n' "$entry"
    done < "$manifest"
}

ads_create_restore_point() {
    local label="${1:-manual}"
    shift || true
    local requested_paths=("$@")
    if (( ${#requested_paths[@]} == 0 )); then
        mapfile -t requested_paths < <(ads_restore_manifest_entries 2>/dev/null || true)
    fi
    if (( ${#requested_paths[@]} == 0 )); then
        log_warning "No paths defined for restore point creation."
        return 0
    fi

    local expanded_paths=()
    local path
    for path in "${requested_paths[@]}"; do
        local expanded
        expanded=$(ads_expand_path "$path" 2>/dev/null || true)
        if [[ -n "$expanded" && -e "$expanded" ]]; then
            expanded_paths+=("$expanded")
        fi
    done

    if (( ${#expanded_paths[@]} == 0 )); then
        log_warning "Restore point skipped; none of the declared paths exist."
        return 0
    fi

    local backup_dir="${ADS_BACKUP_DIR:-$HOME/.automatic_dev_setup/backup}"
    ads_ensure_directory "$backup_dir"
    local timestamp archive manifest
    timestamp="$(date -u '+%Y%m%d-%H%M%S')"
    archive="${backup_dir}/restore-${timestamp}-${label}.tar.gz"
    manifest="$(mktemp /tmp/automatic-dev-restore.XXXXXX)"
    printf '%s\n' "${expanded_paths[@]}" > "$manifest"
    local exclude_args=()
    if [[ -n "$backup_dir" ]]; then
        exclude_args+=(--exclude "$backup_dir")
    fi
    if tar -czf "$archive" "${exclude_args[@]}" -T "$manifest"; then
        log_success "Restore point created: $archive"
    else
        log_error "Failed to create restore point at $archive"
        rm -f "$archive"
        rm -f "$manifest"
        return 1
    fi
    rm -f "$manifest"
    return 0
}

ads_module_progress_file() {
    local runtime_dir="${ADS_RUNTIME_DIR:-$HOME/.automatic_dev_setup/runtime}"
    ads_ensure_directory "$runtime_dir"
    printf '%s/module-progress.log\n' "$runtime_dir"
}

ads_record_module_event() {
    local module="$1"
    local status="$2"
    [[ -z "$module" || -z "$status" ]] && { log_error "ads_record_module_event requires module name and status."; return 1; }
    local progress_file
    progress_file="$(ads_module_progress_file)"
    printf '%s\t%s\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$module" "$status" >> "$progress_file"
}

ads_last_successful_module() {
    local progress_file
    progress_file="$(ads_module_progress_file)"
    [[ -f "$progress_file" ]] || return 1
    awk '$3 == "SUCCESS" {last=$2} END {if (last) print last}' "$progress_file"
}
