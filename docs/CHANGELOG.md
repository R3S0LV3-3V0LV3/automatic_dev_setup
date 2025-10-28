# Changelog

## 3.0.0 (2024-10-20)
- Rebranded the suite as **Automatic Dev Setup** and relocated installation to `~/automatic_dev_setup`.
- Refactored configuration, modules, and documentation to remove Le Wagon/Imperial specific paths and naming.
- Added automated bootstrap script that copies the suite, ensures executables, and runs the orchestrator from the installed location.
- Updated validation tooling, templates, and maintenance jobs to align with the new workspace under `~/coding_environment`.
- Consolidated quick-start documentation into `README.md` to avoid duplicate guidance.
- Introduced a tidy layout: `install.sh`/`preflight.sh`/`troubleshooting.sh` at the root, operations helpers in `operations_setup/` and `operations_support/`, core assets in dedicated directories, and references in `docs/`.
- Added `troubleshooting.sh` with code-aware, interactive remediation and failure-code logging, plus module wrappers in `operations_support/`.
