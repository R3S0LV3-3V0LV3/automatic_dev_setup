# Automatic Dev Setup Manifest

## Root Layout
- `README.md` — primary quick-start and overview.
- `install.sh`, `preflight.sh`, `troubleshooting.sh` — user-facing scripts for installation and recovery.
- `operations_setup/` — wrapper scripts to rerun specific modules (03, 04, 08).
- `operations_support/` — troubleshooting, repair, and validation helpers (09, 10, 11).
- `core/` — orchestrator plus numbered modules `01`–`10`.
- `config/`, `lib/`, `templates/`, `testing/`, `tools/`, `maintenance/` — implementation assets.
- `docs/` — supporting documentation (`MANIFEST.md`, `CHANGELOG.md`, `TROUBLESHOOTING.md`, `validation-verification.md`).

## operations_setup/
- `03-automatic-dev-shell.sh` — reruns module 03 (shell environment).
- `04-automatic-dev-python.sh` — reruns module 04 (Python ecosystem).
- `08-automatic-dev-optimize.sh` — reruns module 08 (system optimisation).

## operations_support/
- `09-automatic-dev-validate.sh` — reruns module 09 (integration validation).
- `10-automatic-dev-repair.sh` — replays all modules and validation for drift correction.
- `11-automatic-dev-troubleshoot.sh` — interactive remediation driven by recorded failure codes.

## core/
- `00-automatic-dev-orchestrator.sh` — primary execution entry point (`--standard`, `--performance`, `--start`, `--only`, `--skip`, `--dry-run`).
- Modules `01`–`10` — bootstrap through maintenance setup.

## Supporting Assets
- `automatic-dev-config.env` — shared configuration exporting the `ADS_*` variables.
- `config/` — Homebrew Brewfile, Python requirements, and constraint pinning.
- `lib/` — shared helpers (`automatic-dev-core.sh`, error handling, logging, validation).
- `templates/` — starter notebooks, scripts, Docker assets, and cheat sheets.
- `testing/` — `automatic-dev-tests.sh` validation harness invoked by module 09.
- `tools/` — `automatic-dev-container-suite.sh` for Colima/kind/Kubernetes helpers.
- `maintenance/` — launchd artefacts; module 10 writes `com.automatic-dev.maintenance.plist` here.
- `docs/` — `MANIFEST.md`, `CHANGELOG.md`, `TROUBLESHOOTING.md`, `validation-verification.md`.

## Generated Paths (runtime)
- `~/automatic_dev_setup` — installed copy of the suite (mirrors this repository layout).
- `~/coding_environment` — primary workspace and managed venv root (`~/coding_environment/.venvs/automatic-dev`).
- `~/.automatic_dev_setup/logs` — execution, validation, and troubleshooting logs (retained 30 days).
- `~/.automatic_dev_setup/runtime` — transient assets.
- `~/.automatic_dev_setup/backup` — maintenance scaffolding.

All components adhere to the reliability expectations documented in `docs/validation-verification.md`.
