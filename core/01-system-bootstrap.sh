#!/usr/bin/env bash
# =============================================================================
# 01-system-bootstrap.sh - Automatic Dev Setup
# Purpose: Perform baseline system validation, directory preparation, and security posture setup.
# Version: 3.0.0
# Dependencies: bash, xattr, mkdir, sw_vers, sysctl, softwareupdate
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M01}"

prepare_gatekeeper() {
    log_info "Sanitising Gatekeeper quarantine attributes..."
    xattr -dr com.apple.quarantine "$SUITE_ROOT" 2>/dev/null || true
}

prepare_directories() {
    log_info "Preparing critical directory structure..."
    local directories=(
        "$ADS_INSTALL_ROOT"
        "$ADS_WORKSPACE_ROOT"
        "$ADS_TOOLS_DIR"
        "$ADS_LOG_ROOT"
        "$ADS_RUNTIME_DIR"
        "$ADS_BACKUP_DIR"
        "$ADS_TEMPLATE_DEST"
        "$ADS_VENV_ROOT"
    )

    for dir in "${directories[@]}"; do
        ads_ensure_directory "$dir"
    done
}

write_project_guide() {
    local guide_path="$ADS_PROJECT_GUIDE"
    local workspace="$ADS_WORKSPACE_ROOT"
    local legacy_dir="${workspace}/projects"

    if [[ -d "$legacy_dir" ]]; then
        if [[ -z "$(ls -A "$legacy_dir")" ]]; then
            rmdir "$legacy_dir"
            log_info "Removed empty legacy projects directory at $legacy_dir."
        else
            local backup
            backup="${legacy_dir}-legacy-$(date +%Y%m%d%H%M%S)"
            mv "$legacy_dir" "$backup"
            log_warning "Legacy projects directory contained files. Moved to $backup; review before deleting."
        fi
    fi

    ads_ensure_directory "$workspace"
    if [[ -f "$guide_path" ]]; then
        ads_backup_file "$guide_path"
    fi

    cat <<'EOF' > "$guide_path"
# Project Directory Formatting Guide

An effective project layout helps every contributor—from new learners to senior engineers—understand how to build, test, and ship changes quickly. The practices below synthesise guidance from GitHub’s Community Standards, the Open Source Guides, and widely adopted internal playbooks.

## 1. Name Repositories and Root Folders Clearly
- Prefer lowercase-hyphen or lowercase-underscore names (`data-pipeline`, `service_api`).
- When mirroring the repo locally, match the repository name exactly.
- Avoid spaces; OS-specific quirks disappear and scripts stay portable.

## 2. Provide an Instant Orientation Layer
- Always include a `README.md` at the root describing purpose, quick-start commands, architecture, and contact points.
- Add `docs/` for deeper walkthroughs or RFCs. Link to it from the README.
- Capture runbooks for operations in `docs/runbooks/` or similar.

## 3. Organise Source, Tests, and Assets Predictably
```
project-root/
├── README.md
├── docs/
├── src/ or app/          # primary source code
├── tests/ or spec/       # automated tests grouped by feature
├── scripts/              # helper CLI scripts (deploy, data seeding)
├── config/               # sample configuration (yaml, json, env)
└── infra/                # IaC, Dockerfiles, manifests
```
- Keep generated artifacts (build outputs, virtual environments, notebook outputs) out of version control by listing them in `.gitignore`.
- Co-locate language-specific metadata (e.g., `pyproject.toml`, `package.json`, `go.mod`) at the root for tool discovery.

## 4. Make Environments Reproducible
- Check in example environment files (`.env.example`, `config/settings.example.yml`).
- Document prerequisites (runtime versions, Homebrew packages, container images) in the README.
- Use lock files (`requirements.txt`, `poetry.lock`, `package-lock.json`) to pin dependencies.

## 5. Version Control Hygiene
- Initialise git repositories inside the project root.
- Enable GitHub Actions or CI workflows alongside the code under `.github/workflows/`.
- Adopt a branching strategy (e.g., trunk-based with short-lived feature branches) and describe it in the README.

## 6. Documentation & Licensing Essentials
- Include `LICENSE` (choose an OSI-approved license when appropriate). GitHub’s license chooser: https://choosealicense.com
- Maintain a `CHANGELOG.md` or release notes when publishing versions.
- Provide contributor guidance (`CONTRIBUTING.md`) once multiple developers collaborate.

## 7. Keep Data & Secrets Out of the Repo
- Do not commit production credentials, tokens, or private datasets.
- Reference secrets via environment variables or secure secret stores.
- When sample data is required, provide sanitised fixtures under `fixtures/` with clear labels.

## 8. Onboarding Checklist
1. Clone the repo into `~/__github_repo`.
2. Skim `README.md` and follow the quick-start path (setup scripts, environment activation).
3. Run the test suite (`npm test`, `pytest`, etc.) to verify the installation.
4. Open the roadmap/backlog to understand active work streams.

This guide is intentionally concise yet precise. Adhering to it ensures new contributors can reason about any project within minutes while giving experienced engineers an industry-standard baseline for structure and hygiene.
EOF

    log_success "Project formatting guide written to $guide_path"
}

prepare_shell_rc() {
    local zprofile="$HOME/.zprofile"
    local zshrc="$HOME/.zshrc"

    if [[ ! -f "$zprofile" ]]; then
        touch "$zprofile"
        log_info "Created $zprofile"
    fi

    if [[ ! -f "$zshrc" ]]; then
        cat > "$zshrc" <<'EOF'
# Managed by Automatic Dev Setup
export ZDOTDIR="$HOME"
EOF
        log_info "Created base $zshrc"
    else
        ads_backup_file "$zshrc"
    fi
}

ensure_software_updates() {
    ads_require_sudo
    log_info "Checking for pending macOS software updates..."
    if softwareupdate -l >/dev/null 2>&1; then
        log_info "Software update check complete."
    else
        log_warning "Unable to check software updates (may require GUI interaction)."
    fi
}

ensure_timezone() {
    if [[ -z "${ADS_TIMEZONE:-}" ]]; then
        log_info "Timezone not specified; skipping automatic configuration."
        return 0
    fi
    ads_require_sudo
    sudo systemsetup -settimezone "$ADS_TIMEZONE" >/dev/null 2>&1 || log_warning "Failed to set timezone to ${ADS_TIMEZONE}."
}

main() {
    log_header "[01] System Bootstrap"
    prepare_gatekeeper
    ads_run_preflight_checks
    prepare_directories
    write_project_guide
    prepare_shell_rc
    ensure_software_updates
    ensure_timezone
    log_success "System bootstrap completed."
}

main "$@"
