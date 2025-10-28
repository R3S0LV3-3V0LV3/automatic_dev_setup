#!/usr/bin/env bash
# =============================================================================
# 04-python-ecosystem.sh - Automatic Dev Setup
# Purpose: Provision Python toolchain via pyenv, establish virtual environments, and install data science stacks.
# Version: 3.0.0
# Dependencies: bash, pyenv, python, pip
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M04}"

export PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto --enable-shared"

ensure_brew_formula() {
    local formula="$1"
    local friendly="${2:-$1}"
    local short_name="${formula##*/}"
    if ! brew list --formula "$short_name" >/dev/null 2>&1; then
        log_info "Installing required Homebrew formula: ${friendly}"
        if ! ads_retry "brew install ${formula}" brew install "$formula"; then
            log_error "Failed to install Homebrew dependency '${friendly}'."
            return 1
        fi
    fi
}

configure_build_flags() {
    local ldflags=()
    local cppflags=()
    local pkgconfig_paths=()

    for formula in openssl@3 readline tcl-tk@8; do
        local prefix
        prefix=$(brew --prefix "$formula" 2>/dev/null || true)
        if [[ -z "$prefix" ]]; then
            log_warning "Homebrew prefix not found for '${formula}'. Python builds may fail."
            continue
        fi
        [[ -d "$prefix/lib" ]] && ldflags+=("-L${prefix}/lib")
        [[ -d "$prefix/include" ]] && cppflags+=("-I${prefix}/include")
        [[ -d "$prefix/lib/pkgconfig" ]] && pkgconfig_paths+=("${prefix}/lib/pkgconfig")
    done

    if (( ${#ldflags[@]} )); then
        local joined_ld
        joined_ld="$(printf '%s ' "${ldflags[@]}")"
        joined_ld="${joined_ld% }"
        joined_ld="${joined_ld//$'\n'/ }"
        joined_ld="${joined_ld//$'\r'/ }"
        joined_ld="${joined_ld//$'\t'/ }"
        export LDFLAGS="$joined_ld"
    else
        unset LDFLAGS
    fi
    if (( ${#cppflags[@]} )); then
        local joined_cpp
        joined_cpp="$(printf '%s ' "${cppflags[@]}")"
        joined_cpp="${joined_cpp% }"
        joined_cpp="${joined_cpp//$'\n'/ }"
        joined_cpp="${joined_cpp//$'\r'/ }"
        joined_cpp="${joined_cpp//$'\t'/ }"
        export CPPFLAGS="$joined_cpp"
    else
        unset CPPFLAGS
    fi

    if (( ${#pkgconfig_paths[@]} )); then
        local joined_pkgconfig
        joined_pkgconfig="$(IFS=:; echo "${pkgconfig_paths[*]}")"
        if [[ -n "${PKG_CONFIG_PATH:-}" ]]; then
            export PKG_CONFIG_PATH="${joined_pkgconfig}:${PKG_CONFIG_PATH}"
        else
            export PKG_CONFIG_PATH="${joined_pkgconfig}"
        fi
    fi
}

prepare_python_build_dependencies() {
    ensure_brew_formula "openssl@3" "openssl@3"
    ensure_brew_formula "readline" "readline"
    ensure_brew_formula "tcl-tk@8" "tcl-tk@8"
    configure_build_flags

    local tcltk_prefix
    tcltk_prefix=$(brew --prefix tcl-tk@8 2>/dev/null || true)
    if [[ -n "$tcltk_prefix" ]]; then
        local tcl_include="-I${tcltk_prefix}/include"
        local tcl_libs="-L${tcltk_prefix}/lib -ltk8.6 -ltcl8.6"
        export PYTHON_CONFIGURE_OPTS="${PYTHON_CONFIGURE_OPTS} --with-tcltk-includes=${tcl_include} --with-tcltk-libs='${tcl_libs}'"
        export TCL_LIBRARY="${tcltk_prefix}/lib/tcl8.6"
        export TK_LIBRARY="${tcltk_prefix}/lib/tk8.6"
        export PYTHON_BUILD_TCLTK_HEADER_PATH="${tcltk_prefix}/include"
        export PYTHON_BUILD_TCLTK_LIB_PATH="${tcltk_prefix}/lib"
    fi
}

ensure_pyenv_shell_integration() {
    local zprofile="$HOME/.zprofile"
    ads_append_once 'export PYENV_ROOT="$HOME/.pyenv"' "$zprofile"
    ads_append_once 'if [[ -d "$PYENV_ROOT/bin" ]]; then export PATH="$PYENV_ROOT/bin:$PATH"; fi' "$zprofile"
    ads_append_once 'eval "$(pyenv init --path)"' "$zprofile"
}

ensure_pyenv_init() {
    ensure_brew_formula "pyenv" "pyenv"

    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    if [[ -d "$PYENV_ROOT/bin" ]]; then
        export PATH="$PYENV_ROOT/bin:$PATH"
    fi

    if ! command -v pyenv >/dev/null 2>&1; then
        log_warning "pyenv executable not found in PATH; attempting Homebrew reinstall."
        if ! ads_retry "brew reinstall pyenv" brew reinstall pyenv; then
            log_error "pyenv reinstall failed."
            exit 1
        fi
        hash -r
    fi

    if ! command -v pyenv >/dev/null 2>&1; then
        log_error "pyenv not available after reinstall. Aborting Python ecosystem setup."
        exit 1
    fi

    ensure_pyenv_shell_integration
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
}

install_python_versions() {
    prepare_python_build_dependencies

    local versions=(
        "$ADS_PYTHON_GLOBAL"
        "$ADS_PYTHON_LEGACY"
        "$ADS_PYTHON_FUTURE"
    )
    for version in "${versions[@]}"; do
        [[ -z "$version" ]] && continue
        log_info "Ensuring Python ${version} via pyenv..."
        if pyenv install -s "$version"; then
            log_success "Python ${version} is available."
        else
            log_warning "pyenv could not provision ${version}; validate pyenv definitions and rerun module 04."
        fi
    done
    if pyenv versions --bare | grep -qx "$ADS_PYTHON_GLOBAL"; then
        pyenv global "$ADS_PYTHON_GLOBAL"
        pyenv rehash
        log_success "pyenv global forced to $ADS_PYTHON_GLOBAL (primary runtime)."
    else
        log_warning "Requested global Python version $ADS_PYTHON_GLOBAL not installed; pyenv global unchanged."
    fi
}

ensure_pipx_path() {
    if command -v pipx >/dev/null 2>&1; then
        pipx ensurepath >/dev/null 2>&1 || true
    fi
}

create_automatic_dev_venv() {
    ads_ensure_directory "$ADS_VENV_ROOT"
    local python_bin=""
    if command -v pyenv >/dev/null 2>&1; then
        python_bin="$(pyenv which python 2>/dev/null || true)"
    fi
    if [[ -z "$python_bin" ]]; then
        python_bin="$(command -v python3 || true)"
    fi
    if [[ -z "$python_bin" ]]; then
        log_error "No Python interpreter available to create virtual environment."
        return 1
    fi
    local recreate_env=0
    if [[ -d "$ADS_VENV_DEFAULT" && -x "$ADS_VENV_DEFAULT/bin/python" ]]; then
        local venv_version
        venv_version="$("$ADS_VENV_DEFAULT/bin/python" -c 'import platform; print(platform.python_version())' 2>/dev/null || echo "unknown")"
        if [[ "$venv_version" != "$ADS_PYTHON_GLOBAL" ]]; then
            log_info "Existing virtual environment uses Python ${venv_version}; recreating with ${ADS_PYTHON_GLOBAL}."
            recreate_env=1
        fi
    else
        recreate_env=1
    fi

    if (( recreate_env )); then
        rm -rf "$ADS_VENV_DEFAULT"
        log_info "Creating Automatic Dev virtual environment at $ADS_VENV_DEFAULT"
        "$python_bin" -m venv "$ADS_VENV_DEFAULT"
    else
        log_info "Automatic Dev virtual environment already present and matches Python ${ADS_PYTHON_GLOBAL}."
    fi
}

bootstrap_python_packages() {
    if [[ ! -f "$ADS_REQUIREMENTS_FILE" || ! -f "$ADS_CONSTRAINTS_FILE" ]]; then
        log_error "Requirements or constraints file missing. Ensure config files are in place."
        exit 1
    fi
    if [[ ! -f "$ADS_VENV_DEFAULT/bin/activate" ]]; then
        log_error "Automatic Dev virtual environment activation script not found at $ADS_VENV_DEFAULT/bin/activate"
        return 1
    fi

    # shellcheck disable=SC1090
    source "$ADS_VENV_DEFAULT/bin/activate"
    if ! pip install --upgrade pip setuptools wheel; then
        log_warning "Failed to upgrade pip tooling within Automatic Dev venv."
    fi
    if ! pip install --requirement "$ADS_REQUIREMENTS_FILE" --constraint "$ADS_CONSTRAINTS_FILE"; then
        log_warning "Failed to install one or more Python requirements. Review pip output and rerun."
    fi
    python -m ipykernel install --user --name automatic-dev-py311 --display-name "Automatic Dev Python 3.11" >/dev/null 2>&1 || log_warning "ipykernel registration encountered issues."
    deactivate
}

register_pyenv_virtualenvs() {
    if command -v pyenv-virtualenv >/dev/null 2>&1; then
        log_info "Ensuring pyenv virtualenvs are available..."
        pyenv virtualenv "$ADS_PYTHON_GLOBAL" automatic-dev-global 2>/dev/null || true
    fi
}

write_project_python_version() {
    local target_dir="$ADS_SUITE_ROOT"
    if [[ ! -d "$target_dir" ]]; then
        log_warning "Automatic Dev Setup directory ${target_dir} not found; skipping .python-version pin."
        return 0
    fi
    local version_file="${target_dir}/.python-version"
    if [[ -f "$version_file" ]]; then
        local existing
        existing="$(<"$version_file")"
        if [[ "$existing" == "$ADS_PYTHON_GLOBAL" ]]; then
            log_info ".python-version already pinned to ${ADS_PYTHON_GLOBAL} in ${target_dir}."
            return 0
        fi
        ads_backup_file "$version_file"
    fi
    printf '%s\n' "$ADS_PYTHON_GLOBAL" > "$version_file"
    log_success "Pinned pyenv local version ${ADS_PYTHON_GLOBAL} for ${target_dir}."
}

main() {
    log_header "[04] Python Ecosystem"
    ads_require_command brew "Install Homebrew via module 02"
    ensure_pyenv_init
    install_python_versions
    ensure_pipx_path
    create_automatic_dev_venv
    bootstrap_python_packages
    register_pyenv_virtualenvs
    write_project_python_version
    log_success "Python ecosystem configured."
}

main "$@"
