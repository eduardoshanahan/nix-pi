# `nix-pi` Documentation Index

This file is the local documentation index for repository-level documents in
`nix-pi`.

Use `README.md` for the repo overview and ownership boundary.
Use this file when you are already in `nix-pi` and want the shortest path to
the right class of document.

## Setup And Provisioning

- `docs/setup/SETUP.md`
- `docs/setup/PROVISIONING.md`
- `docs/setup/SECRETS.md`

## Operations Reference

- `docs/operations/REMOTE_BUILDS.md`
- `docs/operations/HOST_RUNTIME_DIVERGENCES.md`
- `docs/operations/UPTIME_KUMA_MONITOR_POLICY.md`

## Recovery

- `docs/recovery/backup_strategy.md`
- `docs/recovery/reflash_rejoin_node_runbook.md`

## Decisions

- `docs/decisions/CONFIDENTIALITY.md`
- `docs/decisions/ADR-0001-nix-flakes.md`
- `docs/decisions/ADR-0002-prek-gitleaks.md`

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
