# `nix-pi/docs`

This directory is the local documentation index for host-lifecycle and
host-policy documents owned by `nix-pi`.

Use `../README.md` for the top-level repo overview.
Use this file when you are already in `nix-pi/docs/` and want the shortest path
to the right document.

## Stable Operator Docs

- `SETUP.md`
  - workstation and local environment setup
- `PROVISIONING.md`
  - image build, flash, and first-boot flow
- `SECRETS.md`
  - host-side SOPS provisioning workflow
- `REMOTE_BUILDS.md`
  - remote builder/signing model and recovery notes
- `COMMIT_AND_HOOKS_POLICY.md`
  - commit and hook workflow expectations

## Current Host-Policy Docs

- `HOST_RUNTIME_DIVERGENCES.md`
  - canonical register of intentional host-specific runtime differences from
    shared `nix-services` behavior
- `UPTIME_KUMA_MONITOR_POLICY.md`
  - canonical host-owned policy and exceptions for declarative Uptime Kuma
    monitors on `pi-node-b`
- `OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - operator quick checks and deployed-service notes that are too detailed for
    the top-level repo README

## Session Continuity And Plans

- `CODEX_SANDBOX_NIX_DAEMON_RUNBOOK.md`
- `KUMA_AUTHENTIK_LIMITATION_NOTE_2026-03-06.md`
- `N8N_RPI_BOX_02_PHASE1_PLAN.md`
- `STORAGE_DIRECTORY_AUDIT_AND_REMEDIATION_PLAN.md`

These are useful context documents, but they are not the first place to look
for core host lifecycle or host-runtime truth.

## Boundary Reminder

- Shared service module behavior/contracts:
  - `../../nix-services/services/*/README.md`
- Shared documentation sync gate:
  - `../../nix-services/DOC_SYNC_CHECKLIST.md`
