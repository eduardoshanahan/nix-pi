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

- `docs/policy/CONFIDENTIALITY.md`
- `docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`

## Recovery Docs

- `docs/recovery/backup_strategy.md`
- `docs/recovery/reflash_rejoin_node_runbook.md`

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
