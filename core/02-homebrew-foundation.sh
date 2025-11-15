#!/usr/bin/env bash
# =============================================================================
# 02-homebrew-foundation.sh - Automatic Dev Setup
# Purpose: Install and configure Homebrew, taps, and core packages.
# Version: 3.0.0
# Dependencies: bash, curl, git, brew
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M02}"

BREW_PREFIX_ARM64="/opt/homebrew"
BREW_PREFIX_INTEL="/usr/local"
MODE="${ADS_MODE:-standard}"

PERFORMANCE_FORMULAE=(
    "hyperfine"
    "bandwhich"
    "glances"
    "wrk"
    "siege"
    "hey"
    "tokei"
)

PERFORMANCE_CASKS=(
    "istat-menus"
    "bettertouchtool"
    "karabiner-elements"
)

install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        log_success "Homebrew already installed."
        return 0
    fi

    local install_cmd='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    log_info "Installing Homebrew..."
    ads_retry "Homebrew install" bash -c "$install_cmd"
}

configure_homebrew_path() {
    local brew_prefix="$BREW_PREFIX_ARM64"
    if [[ "$(ads_detect_arch)" != "arm64" ]]; then
        brew_prefix="$BREW_PREFIX_INTEL"
    fi

    if [[ ! -x "$brew_prefix/bin/brew" ]]; then
        log_error "Homebrew binary not found at expected prefix: $brew_prefix"
        return 1
    fi

    eval "$("$brew_prefix/bin/brew" shellenv)"

    ads_append_once "eval \"\$($brew_prefix/bin/brew shellenv)\"" "$HOME/.zprofile"
    log_success "Homebrew environment configured in ~/.zprofile"
}

prune_deprecated_taps() {
    local deprecated_taps=(
        "homebrew/cask"
        "homebrew/cask-fonts"
        "homebrew/cask-versions"
        "homebrew/services"
    )

    for tap in "${deprecated_taps[@]}"; do
        if brew tap | grep -q "^${tap}$"; then
            log_warning "Removing deprecated tap: ${tap}"
            brew untap "$tap" >/dev/null 2>&1 || log_warning "Unable to untap ${tap}; manual cleanup may be required."
        fi
    done
}

resolve_terraform_conflict() {
    if brew list --formula terraform >/dev/null 2>&1; then
        log_warning "Detected existing core terraform formula; removing to avoid tap conflicts."
        if ! brew uninstall --force terraform >/dev/null 2>&1; then
            log_error "Failed to remove conflicting terraform formula."
        fi
    fi
}

resolve_mongodb_conflicts() {
    local desired="mongodb-community@7.0"
    local installed
    installed=$(brew list --formula 2>/dev/null | grep '^mongodb-community@' || true)
    while read -r formula; do
        [[ -z "$formula" ]] && continue
        [[ "$formula" == "$desired" ]] && continue
        log_warning "Removing conflicting MongoDB formula '${formula}' before installing ${desired}."
        brew uninstall --force "$formula" >/dev/null 2>&1 || log_error "Failed to remove conflicting MongoDB formula '${formula}'."
    done <<< "$installed"

    if brew list --formula mongodb-community >/dev/null 2>&1; then
        log_warning "Removing unversioned mongodb-community to prevent symlink conflicts."
        brew services stop mongodb-community >/dev/null 2>&1 || true
        brew uninstall --force mongodb-community >/dev/null 2>&1 || log_error "Failed to remove mongodb-community."
    fi
}

preflight_package_conflicts() {
    resolve_terraform_conflict
    resolve_mongodb_conflicts
}

tap_repositories() {
    local taps=(
        "mongodb/brew"
        "hashicorp/tap"
        "supabase/tap"
        "heroku/brew"
        "jesseduffield/lazygit"
        "charmbracelet/tap"
        "universal-ctags/universal-ctags"
        "mas-cli/tap"
    )

    for tap in "${taps[@]}"; do
        if brew tap | grep -q "^${tap}$"; then
            log_debug "Tap already added: $tap"
            continue
        fi
        if ads_retry "brew tap $tap" brew tap "$tap"; then
            continue
        fi
        log_warning "Continuing without tap: ${tap} (tap command failed)."
    done
}

brew_update_and_doctor() {
    if ! ads_retry "brew update" brew update; then
        log_warning "brew update encountered persistent issues; review brew diagnostics."
    fi
    if brew doctor >/dev/null; then
        log_success "brew doctor passed."
    else
        log_warning "brew doctor reported issues. Review output with 'brew doctor'."
    fi
}

repair_homebrew_formulae() {
    log_info "Scanning for missing Homebrew dependencies..."
    local missing_output
    if ! missing_output=$(brew missing 2>/dev/null); then
        log_warning "brew missing command unavailable; skipping formula integrity check."
        return 0
    fi

    if [[ -z "${missing_output// }" ]]; then
        log_success "No missing formula dependencies detected."
        return 0
    fi

    while read -r line; do
        [[ -z "$line" ]] && continue
        local formula="${line%%:*}"
        local dependency="${line##*: }"
        log_warning "Formula '${formula}' is missing dependency '${dependency}'. Attempting repair..."
        if brew install "$dependency"; then
            log_success "Reinstalled dependency '${dependency}' for '${formula}'."
        else
            log_error "Failed to reinstall dependency '${dependency}'."
        fi
    done <<< "$missing_output"
}

brew_install_bundles() {
    if [[ ! -f "$ADS_BREWFILE" ]]; then
        log_error "Brewfile missing at $ADS_BREWFILE"
        return 1
    fi
    if ! brew bundle install --file="$ADS_BREWFILE"; then
        log_warning "brew bundle encountered errors; attempting granular installation."
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            if [[ "$line" == tap* ]]; then
                continue
            elif [[ "$line" == brew* ]]; then
                local formula
                formula=$(sed -E 's/brew "([^"]+)".*/\1/' <<<"$line")
                if brew list "$formula" >/dev/null 2>&1; then
                    continue
                fi
                if brew install "$formula"; then
                    log_success "Installed formula: $formula"
                else
                    log_warning "Failed to install formula: $formula"
                fi
            elif [[ "$line" == cask* ]]; then
                local cask
                cask=$(sed -E 's/cask "([^"]+)".*/\1/' <<<"$line")
                if brew list --cask "$cask" >/dev/null 2>&1; then
                    continue
                fi
                if brew install --cask "$cask"; then
                    log_success "Installed cask: $cask"
                else
                    log_warning "Failed to install cask: $cask"
                fi
            fi
        done < "$ADS_BREWFILE"
    fi
}

ensure_brewfile_entries_present() {
    local brewfile="$ADS_BREWFILE"
    if [[ ! -f "$brewfile" ]]; then
        log_error "Unable to verify Brewfile state; missing file at $brewfile"
        return 1
    fi

    local dump_file dump_dest
    dump_file="$(mktemp /tmp/automatic-dev-brew-dump.XXXXXX)"
    if ! brew bundle dump --file="$dump_file" --force >/dev/null 2>&1; then
        log_warning "Failed to dump current Brewfile state; continuing with manual verification."
        rm -f "$dump_file"
        dump_file=""
    else
        ads_ensure_directory "$ADS_LOG_ROOT"
        dump_dest="$ADS_LOG_ROOT/brew-state-$(date -u '+%Y%m%d%H%M%S').Brewfile"
        if mv "$dump_file" "$dump_dest"; then
            dump_file="$dump_dest"
        else
            log_warning "Could not preserve Brewfile dump at $dump_dest."
            rm -f "$dump_file"
            dump_file=""
        fi
    fi

    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        local entry_type entry_name
        entry_type=$(awk '{print $1}' <<<"$line")
        entry_name=$(sed -E 's/^[^"]+"([^"]+)".*/\1/' <<<"$line")
        case "$entry_type" in
            tap)
                if ! brew tap | grep -q "^${entry_name}$"; then
                    log_warning "Tap '${entry_name}' missing; attempting to add."
                    ads_retry "brew tap $entry_name" brew tap "$entry_name" || log_warning "Tap '${entry_name}' remains unavailable."
                fi
                ;;
            brew)
                local short_name="${entry_name##*/}"
                if ! brew list --formula "$short_name" >/dev/null 2>&1; then
                    log_warning "Formula '${entry_name}' not installed; attempting remediation."
                    if brew install "$entry_name" >/dev/null 2>&1; then
                        log_success "Installed formula '${entry_name}'."
                    else
                        log_error "Failed to install formula '${entry_name}'."
                    fi
                fi
                ;;
            cask)
                local cask_name="${entry_name##*/}"
                if ! brew list --cask "$cask_name" >/dev/null 2>&1; then
                    log_warning "Cask '${entry_name}' not installed; attempting remediation."
                    if brew install --cask "$entry_name" >/dev/null 2>&1; then
                        log_success "Installed cask '${entry_name}'."
                    else
                        log_error "Failed to install cask '${entry_name}'."
                    fi
                fi
                ;;
        esac
    done < "$brewfile"

    if [[ -n "$dump_file" ]]; then
        log_info "Brew bundle dump saved to $dump_file for audit."
    fi
}

install_performance_packages() {
    if [[ "$MODE" != "performance" ]]; then
        return 0
    fi

    log_header "Performance mode: installing supplemental tooling"

    for formula in "${PERFORMANCE_FORMULAE[@]}"; do
        if brew list "$formula" >/dev/null 2>&1; then
            log_debug "[perf] Formula already present: $formula"
            continue
        fi
        if brew install "$formula"; then
            log_success "[perf] Installed formula: $formula"
        else
            log_warning "[perf] Failed to install formula: $formula"
        fi
    done

    for cask in "${PERFORMANCE_CASKS[@]}"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            log_debug "[perf] Cask already present: $cask"
            continue
        fi
        if brew install --cask "$cask"; then
            log_success "[perf] Installed cask: $cask"
        else
            log_warning "[perf] Failed to install cask: $cask"
        fi
    done
}

main() {
    log_header "[02] Homebrew Foundation"
    log_info "Homebrew installation mode: ${MODE}"

    ads_require_command curl "Install Command Line Tools via 'xcode-select --install'"
    install_homebrew
    configure_homebrew_path
    prune_deprecated_taps
    preflight_package_conflicts
    tap_repositories
    brew_update_and_doctor
    repair_homebrew_formulae
    brew_install_bundles
    ensure_brewfile_entries_present
    install_performance_packages

    log_success "Homebrew foundation established."
}

main "$@"
