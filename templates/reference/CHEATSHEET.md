# Automatic Dev Setup Cheat Sheet

## Core Commands
- `~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh` — run the entire suite.
- `dbstart` / `dbstop` — manage PostgreSQL, Redis, MongoDB services.
- `tfcheck` / `torchcheck` — validate ML acceleration within the managed venv.
- `venv` — auto-activate a local virtual environment in the current project.
- `mkcd <dir>` — create and enter a directory in one step.

## Frequently Used Aliases
- `ll` / `la` / `ls` — enhanced directory listings via `eza`.
- `g`, `gs`, `gcm`, `gpf` — Git shortcuts for common workflows.
- `jl`, `jn`, `js` — Jupyter helpers.
- `dcu`, `dcd`, `dps` — docker-compose helpers.
- `brewup`, `pipup`, `fullup` — maintenance routines.
- `cdads`, `cdcode`, `cdproj` — quick navigation to suite and project directories.

## Environment Variables
- `AUTOMATIC_DEV_HOME` — `${HOME}/automatic_dev_setup`
- `CODE_DIR` — `${HOME}/coding_environment`
- `PROJECTS_DIR` — `${CODE_DIR}/projects`
- `ADS_CACHE_HOME` — `${HOME}/.automatic_dev_setup`
- `NVM_DIR` — `${HOME}/.nvm`

## Troubleshooting Entry Points
- Review `${HOME}/.automatic_dev_setup/logs/` for timestamped execution logs.
- Consult `docs/TROUBLESHOOTING.md` for recovery playbooks (pip conflicts, ML imports, Gatekeeper, services, containers).
- Re-run specific modules with `~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only <module>`.
