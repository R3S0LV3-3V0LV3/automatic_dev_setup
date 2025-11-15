# Validation & Verification Canon

This canon describes the artefacts, checks, and procedures required to certify an Automatic Dev Setup deployment on macOS. Use it to audit fresh installations and to reconcile partially configured machines.

---

- `install.sh` installs the suite into `~/automatic_dev_setup` and launches the orchestrator.
- `core/00-automatic-dev-orchestrator.sh` executes core modules in order; accepts `--standard`, `--performance`, `--start`, `--only`, `--skip`, and `--dry-run`.
- `automatic-dev-config.env` exposes configuration variables (`ADS_*`) consumed by every module.
- Libraries (`lib/automatic-dev-*.sh`) provide logging, error trapping, helper utilities, and preflight validations.
- Modules `core/01`–`core/10` implement the functional pipeline (see §4).
- Configuration lives under `config/` (Brewfile, Python requirements/constraints).
- Templates in `templates/` are synced to `~/coding_environment/__project_templates` by module 07.
- The validation harness sits in `testing/automatic-dev-tests.sh`; container helpers in `tools/automatic-dev-container-suite.sh`.
- Generated runtime paths:
  - `~/automatic_dev_setup` – installed scripts
  - `~/coding_environment` – workspace
  - `~/.automatic_dev_setup/{logs,runtime,backup}` – operational data

---

## 2. Orchestrator Semantics
- Modes: `--standard` (balanced defaults) or `--performance` (heavier tooling, aggressive power settings).
- Flags propagate through wrappers (`operations_setup/03-automatic-dev-shell.sh`, etc.) to the orchestrator.
- Preflight checks (macOS version, architecture, disk, RAM, network, admin rights, Xcode CLT) run before module execution.
- Modules are timed with `ads_measure` and log to `~/.automatic_dev_setup/logs/automatic-dev-YYYYMMDD.log`.

---

## 3. Shared Guarantees & Defaults
| Check | Location | Expected Result | Failure Handling |
|-------|----------|-----------------|------------------|
| macOS version ≥12 | `automatic-dev-validation.sh` | PASS or abort if <12 | Logs error and exits |
| Architecture | `automatic-dev-validation.sh` | Warn on x86_64 | Continues |
| Disk free ≥20 GB | `automatic-dev-validation.sh` | Warn below 50 GB | Error below 20 GB |
| RAM ≥8 GB | `automatic-dev-validation.sh` | Warn if <8 GB | Continues |
| Network connectivity | `automatic-dev-validation.sh` | Ping 8.8.8.8 | Warning on failure |
| Admin privileges | `automatic-dev-validation.sh` | User in `admin` group | Error otherwise |
| Xcode CLT | `automatic-dev-validation.sh` | Installs/prompt | Warning if pending |
| Directory scaffolding | `01-system-bootstrap.sh` | Creates `~/automatic_dev_setup`, `~/coding_environment`, `~/.automatic_dev_setup/*`, and seeds `__project-formatting.txt`/`__project_templates` | Ensured via `ads_ensure_directory` |
| Shell backups | `01-system-bootstrap.sh` | `.zshrc` backup before rewrite | `ads_backup_file` |

---

## 4. Module Expectations
1. **01-system-bootstrap** – clears quarantine, runs preflight, prepares directories, seeds `.zprofile`/`.zshrc`, checks software updates, optional timezone (`ADS_TIMEZONE`).
2. **02-homebrew-foundation** – installs Homebrew (if missing), prunes deprecated taps, applies `Brewfile.automatic-dev`, dumps audit Brewfile (`~/.automatic_dev_setup/logs/brew-state-*.Brewfile`), installs performance extras when mode=`performance`.
3. **03-shell-environment** – ensures zsh default, installs Oh My Zsh + powerlevel10k, fetches plugins, writes `.zprofile` entries, rewrites `.zshrc` with Automatic Dev aliases (`cdads`, `cdproj`, `tfcheck`, `torchcheck`, etc).
4. **04-python-ecosystem** – ensures build deps, installs Python 3.11/3.10/3.12 via pyenv, creates venv at `~/coding_environment/.venvs/automatic-dev`, installs packages using requirements/constraints, registers `automatic-dev-py311` kernel, pins `.python-version`.
5. **05-development-stack** – provisions Node + NVM, Rust (rustup), Go (tools + env), Ruby (rbenv 3.3.4), ensures Colima profile targeting `~/coding_environment`, updates deno/bun.
6. **06-database-systems** – configures PostgreSQL@16 (memory tuned by mode), creates role `automatic_dev` with dev/test databases, writes redis and MongoDB configs bound to localhost, restarts services.
7. **07-project-templates** – rsyncs `templates/` to `~/coding_environment/__project_templates` and refreshes project guidance.
8. **08-system-optimisation** – runs `brew cleanup`, purges stale caches (>30 days), and applies power settings (balanced vs. performance).
9. **09-integration-validation** – executes `testing/automatic-dev-tests.sh` (Python suite, ADS unit harness, version-lock verifier); report stored under `~/.automatic_dev_setup/logs/test-report-*.md`.
10. **10-maintenance-setup** – writes launchd plist `com.automatic-dev.maintenance`, targets nightly `brew update && brew upgrade && brew cleanup && pipx upgrade-all`, ensures backup directories exist.

---

## 5. Documentation & Templates
- `README.md` (root) – quick start, mode guidance, module summaries (see `troubleshooting.sh` for interactive remediation).
- `docs/MANIFEST.md` – component breakdown.
- `docs/TROUBLESHOOTING.md` – remediation playbooks for Python deps, ML acceleration, Homebrew, Gatekeeper, services, containers, and launchd.
- Templates (`.py`, notebooks, Docker) reference `~/coding_environment` and Automatic Dev naming conventions.

---

## 6. Automated Test Matrix (`testing/automatic-dev-tests.sh`)
| Category | Function | Command(s) | Expected Outcome |
|----------|----------|------------|------------------|
| System | `test_macos_version`, `test_architecture`, `test_system_resources` | `sw_vers`, `uname`, `sysctl`, `df` | PASS or WARN when near limits |
| Homebrew | `test_homebrew_installation`, `test_homebrew_health`, `test_homebrew_packages` | `brew --version`, `brew doctor`, `brew list` | All required packages present |
| Python | `test_python_installation`, `test_virtual_environment`, `test_python_packages`, `test_pip_check` | `python3`, venv activation, imports, `pip check` | PASS unless missing packages |
| ML | `test_tensorflow`, `test_pytorch` | `tfcheck`, `torchcheck` | Confirm Apple Metal/MPS where available |
| Databases | `test_postgresql`, `test_redis`, `test_mongodb` | Service status + simple queries | Ensure services reachable |
| Containers | `test_docker_cli`, `test_kubernetes_cli` | `docker`, `colima`, `kubectl`, `helm`, `k9s` | Tools installed (warn if daemons offline) |
| Editor | `test_editor_stack` | `nvim` | Presence check |
| Shell | `test_shell_startup_time` | Python harness launching interactive zsh | Warn if ≥2000 ms |
| Quality | `test_unit_suite` | `tests/unit/test_ads_core.sh` | Validates guard clauses, checksum helpers, module progress tracking |
| Accuracy | `test_version_locks` | `tools/ads-verify-versions.sh` | Confirms tool versions satisfy lock catalogue |

Performance mode asserts additional CLI/casks are installed (hyperfine, glances, BetterTouchTool, etc.).

---

## 7. Manual Post-Install Checklist
1. Open a new terminal; confirm prompt, aliases, and `tfcheck`/`torchcheck`.
2. Activate the managed venv: `source ~/coding_environment/.venvs/automatic-dev/bin/activate`; import core packages.
3. Launch Docker Desktop once if not already running.
4. Optional: `automatic-dev-container-suite.sh colima-start` → `verify` → `colima-stop`.
5. Boot kind cluster: `automatic-dev-container-suite.sh kind-bootstrap`, run `kubectl get nodes`, then `kind-delete`.
6. Validate databases (`psql`, `redis-cli`, `mongosh`).
7. Confirm IDE integration (`code .`, `nvim`).
8. Review `~/.automatic_dev_setup/logs/test-report-*.md` and resolve warnings using `docs/TROUBLESHOOTING.md`.

---

## 8. Idempotency & Drift Repair
- Modules check for existing resources before modifying them (`pyenv install -s`, `brew list`, directory guards, service restarts).
- `operations_support/10-automatic-dev-repair.sh` reruns the orchestrator in the chosen mode and then executes validation.
- The bootstrapper can be rerun; it will refresh the installation under `~/automatic_dev_setup` without harming user projects.

---

## 9. Maintenance & Logs
- Launchd job logs: `~/.automatic_dev_setup/logs/maintenance.log` & `maintenance.err`.
- Daily execution log: `~/.automatic_dev_setup/logs/automatic-dev-YYYYMMDD.log` (rotated at 100 MB, retained 30 days).
- Runtime artefacts persist under `~/.automatic_dev_setup/runtime` and are safe to purge between runs.

---

## 10. Audit Checklist
1. Run `install.sh --standard` (or `--performance`).
2. Inspect terminal output for `[ERROR]`/`[FATAL]`.
3. Execute `operations_support/09-automatic-dev-validate.sh --standard` (match mode) and confirm failures = 0 (warnings acceptable).
4. Review the latest test report for outstanding issues.
5. Verify launchd job status: `launchctl list | grep automatic-dev`.
6. Document key tool versions (`python3`, `node`, `go`, `rustc`, `docker`, `kubectl`).
7. Archive logs and the validation report for compliance records.

Following this canon provides exhaustive assurance that Automatic Dev Setup completed successfully and remains operational.

---

## 11. Restore Points & Resumable Runs
- `install.sh` now triggers `ads_create_restore_point` before any files are modified (disable with `ADS_SKIP_BACKUP=1`). The manifest (`config/restore-manifest.txt`) lists the critical files/directories captured in each archive under `~/.automatic_dev_setup/backup`.
- On-demand snapshots: `./tools/ads-create-restore-point.sh <label> [custom paths…]`.
- Every module write-through is recorded in `~/.automatic_dev_setup/runtime/module-progress.log`. Relaunching the orchestrator with `--resume` starts at the first module following the last successful entry, reducing rework after interruptions.
