# `nix-pi` Documentation Index

This file is the local documentation index for repository-level documents in
`nix-pi`.

Use `README.md` for the repo overview and ownership boundary.
Use this file when you are already in `nix-pi` and want the shortest path to
the right class of document.

## Stable Host Lifecycle Docs

- `docs/lifecycle/SETUP.md`
- `docs/lifecycle/PROVISIONING.md`
- `docs/lifecycle/SECRETS.md`
- `docs/lifecycle/REMOTE_BUILDS.md`

## Stable Host Policy Docs

- `docs/policy/COMMIT_AND_HOOKS_POLICY.md`
- `docs/policy/CONFIDENTIALITY.md`
- `docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
- `docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md`

## Operations Docs

- `docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - pointer to the private operator notes in `../nix-pi-private/docs/operations/`

## Plans And Reference Notes

- `docs/plans/nix_os_homelab_roadmap_checkpoints.md`
- `docs/plans/zero_downtime_dns_migration_checklist.md`
- `docs/plans/N8N_RPI_BOX_02_PHASE1_PLAN.md`
- `docs/plans/STORAGE_DIRECTORY_AUDIT_AND_REMEDIATION_PLAN.md`

These are planning, audit, migration, or rollout references. Unless a new
rollout is actively in progress, they should be read as recovery/expansion
material rather than everyday operator truth.

## Recovery Docs

- `docs/recovery/backup_strategy.md`
- `docs/recovery/reflash_rejoin_node_runbook.md`

## Continuity And Archive Docs

- `docs/continuity/CODEX_SANDBOX_NIX_DAEMON_RUNBOOK.md`
- `docs/continuity/KUMA_AUTHENTIK_LIMITATION_NOTE_2026-03-06.md`
- `docs/continuity/ROOT_SESSION_DOCS_ARCHIVE_SUMMARY_2026-03-18.md`

These preserve useful context across sessions, but they are not the first place
to look for stable host lifecycle or host-runtime truth.

## Prompt / Style Pointers

- `docs/prompts/response_style.md`

## Boundary Reminder

- `README.md`
  - repo overview, ownership boundaries, and main documentation pointers
- `docs/`
  - host lifecycle, policy, and public-safe planning/continuity docs
- `records/`
  - project/session records
- `nixos/hosts/private/`
  - placeholder contract and migration notes for the private companion model
- `../nix-pi-private/modules/`
  - live private shared and host-specific configuration
- `../nix-pi-private/docs/`
  - private operator notes, continuity files, and internal rollout details
- `../nix-services/services/*/README.md`
  - shared service behavior and options
- `../nix-services/docs/policy/DOC_SYNC_CHECKLIST.md`
  - documentation sync gate for cross-repo changes
