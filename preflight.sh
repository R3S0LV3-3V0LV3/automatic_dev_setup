#!/usr/bin/env bash
# =============================================================================
# preflight.sh - Automatic Dev Setup
# Author: Kieran Tandi
# Purpose: Prepare the repository by clearing quarantine flags, ensuring
#          all shell scripts are executable, and updating Bash if requested.
# Version: 2.0.0
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/lib/automatic-dev-env.sh"
ads_enable_traps

# Parse arguments
UPDATE_BASH=0
for arg in "$@"; do
    case "$arg" in
        --update-bash)
            UPDATE_BASH=1
            ;;
        --help)
            echo "Usage: $0 [--update-bash] [--help]"
            echo "Options:"
            echo "  --update-bash  Download and compile latest Bash from source"
            echo "  --help         Show this help message"
            exit 0
            ;;
    esac
done

log_header "[Preflight] Repository Preparation"
ads_clear_quarantine "$REPO_ROOT"

# =============================================================================
# BASH UPDATE FUNCTION
# =============================================================================

update_bash_from_source() {
    log_info "[Preflight] Building Bash from source to keep shells current."

    local bash_version="5.2"
    local bash_patch="37"  # Latest stable patches, always
    local temp_dir="/tmp/bash-update-$$"

    if [[ -f "/usr/local/bin/bash" ]]; then
        local current_version
        current_version=$(/usr/local/bin/bash --version | head -n1)
        log_info "[Preflight] Current Bash: ${current_version}"
    fi

    log_info "[Preflight] Downloading Bash ${bash_version} with patches..."

    mkdir -p "$temp_dir"
    cd "$temp_dir"

    local archive="bash-${bash_version}.tar.gz"
    if ! ads_fetch_with_checksum "$archive" "$temp_dir/$archive"; then
        log_error "[Preflight] Failed to fetch Bash source with checksum verification."
        cd "$REPO_ROOT"
        rm -rf "$temp_dir"
        return 1
    fi

    log_info "[Preflight] Extracting source..."
    tar xzf "$archive"
    cd "bash-${bash_version}"

    log_info "[Preflight] Applying patches (up to ${bash_patch})..."
    for i in $(seq 1 "$bash_patch"); do
        patch_num=$(printf "%03d" "$i")
        patch_file="bash${bash_version//./}-${patch_num}"

        if curl -fsSL -o "${patch_file}" \
           "https://ftp.gnu.org/gnu/bash/bash-${bash_version}-patches/${patch_file}"; then
            log_debug "[Preflight] Applying patch ${patch_num}"
            patch -p0 < "$patch_file" >/dev/null 2>&1 || true
        fi
    done

    log_info "[Preflight] Configuring Bash build..."
    ./configure --prefix=/usr/local \
                --enable-alias \
                --enable-arith-for-command \
                --enable-array-variables \
                --enable-bang-history \
                --enable-brace-expansion \
                --enable-casemod-attributes \
                --enable-casemod-expansions \
                --enable-command-timing \
                --enable-cond-command \
                --enable-cond-regexp \
                --enable-coprocesses \
                --enable-debugger \
                --enable-directory-stack \
                --enable-dparen-arithmetic \
                --enable-extended-glob \
                --enable-help-builtin \
                --enable-history \
                --enable-job-control \
                --enable-multibyte \
                --enable-net-redirections \
                --enable-process-substitution \
                --enable-progcomp \
                --enable-prompt-string-decoding \
                --enable-readline \
                --enable-restricted \
                --enable-select \
                --enable-separate-helpfiles \
                --with-installed-readline \
                >/dev/null 2>&1

    log_info "[Preflight] Building Bash (this may take a few minutes)..."
    make -j"$(sysctl -n hw.ncpu)" >/dev/null 2>&1

    log_info "[Preflight] Installing Bash (will prompt for sudo)..."
    sudo make install >/dev/null 2>&1

    if ! grep -q "/usr/local/bin/bash" /etc/shells; then
        log_info "[Preflight] Adding /usr/local/bin/bash to /etc/shells..."
        echo "/usr/local/bin/bash" | sudo tee -a /etc/shells >/dev/null
    fi

    cd "$REPO_ROOT"
    rm -rf "$temp_dir"

    if [[ -f "/usr/local/bin/bash" ]]; then
        local new_version
        new_version=$(/usr/local/bin/bash --version | head -n1)
        log_success "[Preflight] Bash updated: ${new_version} @ /usr/local/bin/bash"
    else
        log_error "[Preflight] Bash installation verification failed."
        return 1
    fi
}

# =============================================================================
# MAIN PREFLIGHT OPERATIONS
# =============================================================================

# Function to make all shell scripts executable
ads_ensure_executable_scripts() {
    local count=0
    local script_dir="${1:-$REPO_ROOT}"
    
    log_info "[Preflight] Ensuring all shell scripts are executable..."
    
    # Method 1: Try using find with -exec (most portable)
    if command -v find >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do
            if [[ -f "$file" && ! -x "$file" ]]; then
                chmod +x "$file"
                ((count++))
                log_debug "[Preflight] Made executable: $file"
            fi
        done < <(find "$script_dir" -type f -name '*.sh' -print0 2>/dev/null)
    fi
    
    # Method 2: Fallback to glob patterns if find fails
    if [[ $count -eq 0 ]]; then
        # Handle root level .sh files
        for file in "$script_dir"/*.sh; do
            if [[ -f "$file" && ! -x "$file" ]]; then
                chmod +x "$file"
                ((count++))
            fi
        done
        
        # Handle subdirectory .sh files
        for file in "$script_dir"/**/*.sh; do
            if [[ -f "$file" && ! -x "$file" ]]; then
                chmod +x "$file"
                ((count++))
            fi
        done
    fi
    
    # Also ensure the automatic-dev-config.env is readable (it's sourced but not executed)
    if [[ -f "$script_dir/automatic-dev-config.env" ]]; then
        chmod 644 "$script_dir/automatic-dev-config.env"
    fi
    
    if [[ $count -gt 0 ]]; then
        log_success "[Preflight] Made $count shell scripts executable"
    else
        log_info "[Preflight] All shell scripts already executable"
    fi
}

# Execute the function
ads_ensure_executable_scripts "$REPO_ROOT"

# Update Bash if requested
if [[ $UPDATE_BASH -eq 1 ]]; then
    update_bash_from_source
fi

log_success "[Preflight] Complete. You can now run ./install.sh"
