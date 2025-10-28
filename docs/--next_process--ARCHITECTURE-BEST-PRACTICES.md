# Automatic Dev Setup – Architecture & Best Practices

This framework distils guidance from industry-standard literature (Google SRE, AWS Well-Architected, CNCF operator patterns, and SOLID-inspired script design) and maps it to the Automatic Dev Setup codebase.

## Architectural Principles
- **Deterministic orchestration:** Maintain strictly ordered, idempotent modules (00–10). Each module should validate preconditions, emit structured logs, and leave guardrails for reruns (`ads_retry`, `ads_measure`).
- **Fail-fast modules:** Elevate non-zero exits immediately via `set -Eeuo pipefail` and `ads_enable_traps`, ensuring telemetry capture through `ads_record_failure_event`.
- **Separation of concerns:** Keep user-facing orchestration (`core/`), shared logic (`lib/`), configuration (`config/`), and support tooling (`operations_*`, `tools/`) distinct to minimise coupling.
- **Declarative configuration:** Centralise tunables in `automatic-dev-config.env`, export read-only defaults, and avoid inline constants in modules wherever possible.

## SOLID-Inspired Shell Guidelines
- **Single Responsibility (S):** Modules should perform one cohesive workflow segment (e.g., `04-python-ecosystem.sh` focuses exclusively on Python provisioning). Utility functions in `lib/` should remain purpose-specific.
- **Open/Closed (O):** Extend functionality via new modules or helper functions rather than editing orchestrator control flow. The diagnostics catalog introduced in `config/failure-catalog.tsv` exemplifies table-driven extensibility.
- **Liskov Substitution (L):** Ensure helper functions degrade gracefully when inputs unavailable (e.g., missing catalog entries), allowing substitutable implementations without breaking orchestration.
- **Interface Segregation (I):** Keep helper utilities granular (`ads_run`, `ads_measure`, `ads_retry`) so modules depend only on the functionality they require.
- **Dependency Inversion (D):** Consume shared configuration and diagnostics metadata through environment variables and catalog lookups instead of hard-coded paths.

## Operational Guardrails
- **Observability:** Emit human-readable logs (`automatic-dev-*.log`) plus machine-parsable telemetry (`failure-events.jsonl`). Tie every failure code to documentation anchors for swift root cause analysis.
- **Validation cadence:** Run `operations_support/09-automatic-dev-validate.sh` after any change; integrate into CI to detect regressions.
- **Resource stewardship:** Gate heavy installations behind profile toggles (`--standard`, `--performance`), and evaluate disk/RAM thresholds before provisioning (preflight validation).
- **Security posture:** Enforce Gatekeeper sanitisation, TLS trust for package managers, and minimal privilege escalation via `ads_require_sudo`.

## Recommended Next Enhancements
1. **Complexity metrics:** Integrate `shellcheck` and `bashate` in CI, capturing cyclomatic complexity proxies and style adherence.
2. **Policy as code:** Model dependency resolution and throttling policies in YAML (e.g., desired brew taps/formulae) and diff against actual state.
3. **Runtime conformance tests:** Expand `testing/automatic-dev-tests.sh` with smoke checks for each module (services reachable, binaries present).
4. **Knowledge graph:** Persist failure metadata into a lightweight sqlite db for richer analytics (frequency, MTTR), leveraging the JSONL telemetry as ingestion source.

Adhering to these guidelines keeps the suite aligned with modern DevOps expectations while retaining clarity for maintainers and contributors.
