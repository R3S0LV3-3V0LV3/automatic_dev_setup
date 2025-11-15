# Automatic Dev Setup – Troubleshooting & Recovery

For most situations you can run `~/automatic_dev_setup/troubleshooting.sh`. The helper reads recent failure codes, displays diagnostic metadata (severity, category, context) and walks you through the automated playbooks documented below. All remediation commands emit logs to `~/.automatic_dev_setup/logs/`; keep these artefacts for audit tracing.

---

## Failure Code Index

| Code | Module | Severity | Category | Summary |
| --- | --- | --- | --- | --- |
| ADS-M01 | System Bootstrap & Preflight | high | bootstrap | Bootstrap, gatekeeper, or critical directory preparation failed. |
| ADS-M02 | Homebrew Foundation | critical | package-manager | Homebrew tap/install step failed or brew environment is unhealthy. |
| ADS-M03 | Shell Environment | medium | shell | Shell configuration or profile synchronisation did not complete. |
| ADS-M04 | Python Ecosystem | critical | python | Python environment provisioning, dependency resolution, or venv activation failed. |
| ADS-M05 | Development Stack | high | runtimes | Language runtime or toolchain installation failed (Node, Rust, Go, JVM, etc.). |
| ADS-M06 | Database Systems | high | databases | Database service bootstrap or health check failed. |
| ADS-M07 | Project Templates | low | content-sync | Template synchronisation or workspace scaffolding failed. |
| ADS-M08 | System Optimisation | medium | system-tuning | System optimisation, cleanup, or power profile adjustments failed. |
| ADS-M09 | Integration Validation | critical | validation | Validation suite detected runtime or dependency regressions. |
| ADS-M10 | Maintenance Setup | medium | maintenance | Maintenance launchd job provisioning failed or drift detected. |

---

## Resume & Restore Points

- **Resume after an interruption:** `~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --resume` restarts execution at the module immediately following the last recorded success in `~/.automatic_dev_setup/runtime/module-progress.log`. Combine with `--mode performance` if needed. The flag is ignored when `--only` is supplied.
- **Create a manual restore point:** `~/automatic_dev_setup/tools/ads-create-restore-point.sh <label>` archives every path listed in `config/restore-manifest.txt` to `~/.automatic_dev_setup/backup`. Set `ADS_SKIP_BACKUP=1` if you need to bypass the automatic snapshot performed by `install.sh`.

---

## <a id="ads-m01-system-bootstrap"></a>[ADS-M01] System Bootstrap & Preflight

### Gatekeeper Blocks Execution
**Symptom:** macOS flags scripts as untrusted.

**Fix:**
```bash
xattr -dr com.apple.quarantine "~/automatic_dev_setup"
```
Re-run the desired module.

### Directory & Permission Drift
1. Re-run module 01:
   ```bash
   ~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 01-system-bootstrap
   ```
2. Confirm `~/automatic_dev_setup`, `~/.automatic_dev_setup`, and `~/__github_repo` are writable by the invoking user.
3. Inspect `~/.automatic_dev_setup/logs/failure-codes.log` for additional context.

---

## <a id="ads-m02-homebrew-foundation"></a>[ADS-M02] Homebrew Foundation

**Symptom:** Module 02 reports tap/install failures.

**Fix:**
```bash
xcode-select --install
sudo xcode-select --switch /Library/Developer/CommandLineTools
```
If Homebrew installation is corrupt:
```bash
sudo rm -rf /opt/homebrew /usr/local/Homebrew
```
Rerun module 02:
```bash
~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 02-homebrew-foundation
```
Use `brew doctor`, `brew update`, `brew upgrade`, and `brew bundle --file="$ADS_BREWFILE"` to reconcile formulae/casks after the environment is healthy.

---

## <a id="ads-m03-shell-environment"></a>[ADS-M03] Shell Environment

**Symptom:** Shell startup slow (>2s) or profile changes missing.

**Fix:**
```bash
rm -f ~/.oh-my-zsh/cache/.zcompdump*
```
Consider disabling optional plugins in `~/.zshrc`, then rerun module 03:
```bash
~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 03-shell-environment
```

---

## <a id="ads-m04-python-ecosystem"></a>[ADS-M04] Python Ecosystem

### Python Dependency Conflicts (`pip check`)
**Symptom:** Module 09 fails during `pip check`.

**Fix:**
```bash
cd ~/automatic_dev_setup
source automatic-dev-config.env
source "${ADS_VENV_DEFAULT}/bin/activate"
pip install --upgrade pip setuptools wheel
pip install --requirement "${ADS_REQUIREMENTS_FILE}" --constraint "${ADS_CONSTRAINTS_FILE}"
pip check
```
If conflicts persist, update pins in `config/constraints-automatic-dev.txt` and rerun module 04.

### Virtual Environment Corruption
```bash
rm -rf "${ADS_VENV_DEFAULT}"
~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 04-python-ecosystem
```

---

## <a id="ads-m05-development-stack"></a>[ADS-M05] Development Stack Toolchains

### Docker / Colima
**Symptom:** `docker` reports daemon unreachable or Colima fails to start.

**Fix:**
```bash
open -a "Docker"
colima stop || true
colima start --kubernetes 1
colima status
```
If configuration corruption is suspected:
```bash
rm -f ~/.config/colima/default.yaml
~/automatic_dev_setup/tools/automatic-dev-container-suite.sh colima-start
```

### kind / Kubernetes
```bash
~/automatic_dev_setup/tools/automatic-dev-container-suite.sh kind-delete
~/automatic_dev_setup/tools/automatic-dev-container-suite.sh kind-bootstrap
kubectl config use-context kind-automatic-dev
kubectl get nodes
```

### Other Toolchain Failures
1. Re-run module 05:
   ```bash
   ~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 05-development-stack
   ```
2. Inspect `~/.automatic_dev_setup/logs/automatic-dev-*.log` for the failing toolchain (Node.js, Rust, Go, JVM, etc.).

---

## <a id="ads-m06-database-systems"></a>[ADS-M06] Database Systems

### PostgreSQL
```bash
brew services restart postgresql@16
psql -d postgres -c "SELECT NOW();"
tail -n 200 "$(brew --prefix)/var/log/postgresql@16.log"
```

### Redis
```bash
brew services restart redis
redis-cli ping
```

### MongoDB
```bash
brew services restart mongodb-community@7.0
mongosh --eval "db.runCommand({ping:1})"
```

---

## <a id="ads-m07-project-templates"></a>[ADS-M07] Project Templates

**Symptom:** Template synchronisation fails or assets missing in `~/__github_repo/__project_templates`.

**Fix:**
```bash
~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 07-project-templates
```
Confirm `ADS_TEMPLATE_DEST` is writable and remove stale files before rerunning if necessary.

---

## <a id="ads-m08-system-optimisation"></a>[ADS-M08] System Optimisation

**Symptom:** After running performance mode, Mac no longer sleeps automatically or cleanup tasks fail.

**Fix:**
```bash
sudo pmset -a displaysleep 15
sudo pmset -a disksleep 10
sudo pmset -a powernap off
sudo pmset -a autopoweroff 1
sudo pmset -a standby 1
```
Re-run module 08 with `--standard` if desired:
```bash
~/automatic_dev_setup/core/00-automatic-dev-orchestrator.sh --only 08-system-optimisation --mode standard
```
For cleanup drift:
```bash
brew cleanup -s
brew autoremove
```

---

## <a id="ads-m09-integration-validation"></a>[ADS-M09] Integration Validation

### TensorFlow / PyTorch Acceleration
**Symptom:** `tfcheck` or `torchcheck` fails (Module 09).

**Fix:**
1. Confirm Apple GPU availability:
   ```bash
   system_profiler SPDisplaysDataType | grep Metal
   ```
2. Reinstall ML wheels:
   ```bash
   source "${ADS_VENV_DEFAULT}/bin/activate"
   pip install --force-reinstall tensorflow-macos==2.16.2 tensorflow-metal==1.1.0 torch==2.9.0 torchvision torchaudio
   ```
3. Clear pip caches: `rm -rf ~/Library/Caches/pip`.
4. Rerun `tfcheck` / `torchcheck`. For persistent MPS errors, ensure macOS ≥13.3 and reinstall Xcode CLT (`xcode-select --install`).

### Validation Re-run
```bash
~/automatic_dev_setup/operations_support/09-automatic-dev-validate.sh --mode "${ADS_MODE:-standard}"
```
Review `~/.automatic_dev_setup/logs/test-report-*.md` for context and correlate with `failure-events.jsonl` telemetry if available.

---

## <a id="ads-m10-maintenance-setup"></a>[ADS-M10] Maintenance Setup

**Symptom:** Maintenance logs show errors or launchd job inactive.

**Fix:**
```bash
launchctl unload ~/automatic_dev_setup/maintenance/com.automatic-dev.maintenance.plist
launchctl load -w ~/automatic_dev_setup/maintenance/com.automatic-dev.maintenance.plist
tail -n 200 ~/.automatic_dev_setup/logs/maintenance.err
```
Confirm the plist references the installed suite path and that `ADS_MAINTENANCE_ROOT` matches the installed location.

---

## Incident Reporting

1. Capture logs from `~/.automatic_dev_setup/logs/`.
2. Export recent telemetry entries:
   ```bash
   tail -n 20 ~/.automatic_dev_setup/logs/failure-events.jsonl
   ```
3. Document remediation steps.
4. Re-run `~/automatic_dev_setup/operations_support/09-automatic-dev-validate.sh` to confirm resolution.
