# Packaging Workflow Automation — AI Agent Instructions

Purpose: Enable AI agents to work productively in this repo by following the project’s actual architecture, workflows, and conventions documented in README.

## Big Picture

- Flow: n8n webhook → deterministic classifier → OpenAI (temp=0) → Git branch + PR → Jenkins pipeline on Windows agent/ephemeral VM → layered verification → labels/auto-merge.
- Output artifacts per product live under `products/<ProductName>/` and must validate against `templates/manifest.schema.json`.

## Repo Layout (expected)

- `templates/psadt-template/Deploy-Application.ps1.template`: PSADT scaffold with `<installer>` substitution and verification ladder.
- `templates/manifest.schema.json`: JSON Schema for `manifest.json`.
- `scripts/run-candidate-tests.ps1`: Runs candidates in confidence order and performs layered verification.
- `Jenkinsfile`: Declarative pipeline for Windows agents/VMs.
- `products/<ProductName>/`: Folder created per package with AI-generated files.

## PR/Branch Conventions

- Branch name: `ai/PKG-<ticket>-<sha256>` (e.g., `ai/PKG-123-9f3a...`).
- Files to include in PR under `products/<ProductName>/`:
  - `manifest.json` (must pass `templates/manifest.schema.json`).
  - `candidates.json` (array; primary first by `confidence`).
  - `Deploy-Application.ps1` (derived from PSADT template or AI skeleton).
  - `Files/source_installer.exe` (optional download pointer/handled in CI).
  - `README_AI.md` (summarize `human_review`, include raw AI JSON if parsing failed).
- Labels: always `ai-generated`; add `verified-primary` on CI success or `needs-review` if schema/validation fails.

## LLM Output & Validation Rules

- Temperature: 0. Output ONLY JSON matching the schema. If uncertain: use "TODO" and set `human_review: true`.
- `manifest.json` required fields: `product`, `vendor`, `version`, `source_url`, `checksum`, `install_context`, `human_review`.
- `candidates.json` entries: `{ id, command, framework (MSI|Inno|NSIS|InstallShield|Burn|Custom|Unknown), confidence (0..1), rationale }`.
- Primary candidate: highest `confidence`. Commands must use `<installer>` placeholder for substitution.
- Auto-merge policy (enforced upstream): only when Jenkins passes, `human_review=false`, and `confidence_overall >= 0.90`.

## CI/Jenkins Expectations

- `Jenkinsfile` stages: checkout → PSScriptAnalyzer lint → download installer (from `manifest.source_url`) → `scripts/run-candidate-tests.ps1` → archive `test-output/**`.
- Windows agent/VM with PS 7 & PSADT. Tests use layered verification (MSI product code, path hints, shortcuts, optional smoke).
- On failure: preserve logs in `test-output/**` and keep PR in `needs-review`.

## Deterministic Classification Inputs (pre-LLM)

- Detect `file_type` (msi|exe|zip|unknown); provide `strings_snippet` (first N KB) for EXE; extract MSI properties if possible.
- Always compute and record SHA256 of the installer (used in branch name and audit).

## PSADT & Verification Conventions

- PSADT script installs using primary candidate: replace `<installer>` in command.
- Provide `verification_hints` (paths, registry keys, smoke commands). Prefer MSI ProductCode when available.
- On uninstall path, use `manifest.uninstall_command` when present.

## Examples

- Branch: `ai/PKG-456-8a1c2d...`
- Product folder: `products/MyApp/` containing `manifest.json`, `candidates.json`, `Deploy-Application.ps1`.

## Gotchas

- Keep secrets out of prompts/logs; use n8n vault.
- Windows paths/escaping in PowerShell: prefer double-quoted strings; avoid interactive flags.
- Network egress on VMs may be restricted to vendor domains; avoid external dependencies in tests.

## Quick Checks

- Schema validate `manifest.json` before PR; if invalid, set `human_review=true` and still open PR with `needs-review`.
- Run `PSScriptAnalyzer` locally when editing PSADT scripts.
