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

echo "[Preflight] Clearing Gatekeeper quarantine attributes (if present)..."
xattr -dr com.apple.quarantine . 2>/dev/null || true

if command -v chmod >/dev/null 2>&1; then
    echo "[Preflight] Normalising permissions..."
    chmod -RN . 2>/dev/null || true
fi

if command -v chflags >/dev/null 2>&1; then
    echo "[Preflight] Resetting file flags (may prompt for sudo)..."
    if ! chflags -R nouchg,noschg . 2>/dev/null; then
        sudo chflags -R nouchg,noschg .
    fi
fi

# =============================================================================
# BASH UPDATE FUNCTION
# =============================================================================

update_bash_from_source() {
    echo "[Preflight] Right, let's build Bash from source — because Apple's ancient version is... insufficient"
    
    local bash_version="5.2"
    local bash_patch="37"  # Latest stable patches, always
    local temp_dir="/tmp/bash-update-$$"
    
    # See what we're working with currently
    if [[ -f "/usr/local/bin/bash" ]]; then
        current_version=$(/usr/local/bin/bash --version | head -n1)
        echo "[Preflight] Currently running: $current_version"
    fi
    
    echo "[Preflight] Downloading Bash ${bash_version} with patches..."
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Download base version
    if ! curl -fsSL -o "bash-${bash_version}.tar.gz" \
         "https://ftp.gnu.org/gnu/bash/bash-${bash_version}.tar.gz"; then
        echo "[Preflight] ERROR: Failed to download Bash source"
        cd "$REPO_ROOT"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo "[Preflight] Extracting source..."
    tar xzf "bash-${bash_version}.tar.gz"
    cd "bash-${bash_version}"
    
    # Download and apply patches
    echo "[Preflight] Applying patches (up to patch ${bash_patch})..."
    for i in $(seq 1 "$bash_patch"); do
        patch_num=$(printf "%03d" "$i")
        patch_file="bash${bash_version//./}-${patch_num}"
        
        if curl -fsSL -o "${patch_file}" \
           "https://ftp.gnu.org/gnu/bash/bash-${bash_version}-patches/${patch_file}"; then
            echo "[Preflight] Applying patch ${patch_num}..."
            patch -p0 < "$patch_file" >/dev/null 2>&1
        fi
    done
    
    echo "[Preflight] Configuring Bash build..."
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
    
    echo "[Preflight] Building Bash (this may take a few minutes)..."
    make -j"$(sysctl -n hw.ncpu)" >/dev/null 2>&1
    
    echo "[Preflight] Installing Bash (will prompt for sudo)..."
    sudo make install >/dev/null 2>&1
    
    # Add to /etc/shells if not present
    if ! grep -q "/usr/local/bin/bash" /etc/shells; then
        echo "[Preflight] Adding /usr/local/bin/bash to /etc/shells..."
        echo "/usr/local/bin/bash" | sudo tee -a /etc/shells >/dev/null
    fi
    
    # Cleanup
    cd "$REPO_ROOT"
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -f "/usr/local/bin/bash" ]]; then
        new_version=$(/usr/local/bin/bash --version | head -n1)
        echo "[Preflight] SUCCESS: Bash updated to: $new_version"
        echo "[Preflight] Location: /usr/local/bin/bash"
    else
        echo "[Preflight] ERROR: Bash installation verification failed"
        return 1
    fi
}

# =============================================================================
# MAIN PREFLIGHT OPERATIONS
# =============================================================================

echo "[Preflight] Clearing Gatekeeper quarantine attributes (if present)..."
xattr -dr com.apple.quarantine . 2>/dev/null || true

if command -v chmod >/dev/null 2>&1; then
    echo "[Preflight] Normalising permissions..."
    chmod -RN . 2>/dev/null || true
fi

if command -v chflags >/dev/null 2>&1; then
    echo "[Preflight] Resetting file flags (may prompt for sudo)..."
    if ! chflags -R nouchg,noschg . 2>/dev/null; then
        sudo chflags -R nouchg,noschg .
    fi
fi

echo "[Preflight] Ensuring all shell scripts are executable..."
while IFS= read -r -d '' file; do
    chmod 755 "$file"
done < <(find . -type f -name '*.sh' -print0)

# Update Bash if requested
if [[ $UPDATE_BASH -eq 1 ]]; then
    update_bash_from_source
fi

echo "[Preflight] Complete. You can now run ./install.sh"
