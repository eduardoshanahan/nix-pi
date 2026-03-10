# Storage Directory Audit And Remediation Plan

Status: planned for a future session

## Problem statement

The current repository documentation suggests that `/srv/prometheus` is being
used as a shared USB-backed application storage root, not just as Prometheus
storage.

That is undesirable because:

- the path name implies Prometheus ownership
- multiple unrelated services appear to depend on it
- documentation and implementation may have drifted
- future service placement decisions become harder when storage boundaries are
  unclear

## Why this audit is needed

Before introducing new services with persistent storage, we need to verify:

1. what the documentation says
1. what is actually implemented on hosts
1. which uses are intentional
1. which uses should be migrated to dedicated paths

## Documented uses currently found

The following documentation references were identified:

- Prometheus data:
  - `nix-services/services/prometheus/README.md`
  - documented path: `/srv/prometheus/data`
- OwnTracks Recorder:
  - `nix-services/services/owntracks-recorder/README.md`
  - documented path: `/srv/prometheus/owntracks`
- TimeTagger:
  - `nix-services/services/timetagger/README.md`
  - documented path: `/srv/prometheus/timetagger`
- Home Assistant:
  - `nix-services/services/home-assistant/README.md`
  - documented path: `/srv/prometheus/home-assistant`
- SMTP relay backups on `pi-node-b`:
  - `nix-pi/README.md`
  - documented path: `/srv/prometheus/backups/smtp-relay/...`

## Audit goals

- Build a complete inventory of all `/srv/prometheus` usage in docs and code.
- Verify the real directories on `pi-node-b`.
- Identify which services are using the same underlying USB-backed filesystem.
- Decide whether `/srv/prometheus` should:
  - remain Prometheus-only
  - become a generic storage root under a better name
  - be split into per-service dedicated top-level paths under `/srv`

## Working assumption

Preferred end state:

- `/srv/prometheus` is reserved for Prometheus data only
- unrelated services move to dedicated paths such as:
  - `/srv/home-assistant`
  - `/srv/owntracks`
  - `/srv/timetagger`
  - `/srv/backups/smtp-relay`
  - `/srv/n8n`

This assumption must be validated against actual implementation and operational
constraints before changing anything.

## Required investigation in the next session

1. Search repo configuration, not just Markdown docs:
   - `nix-services/services/**`
   - `nix-pi/nixos/**`
   - private host config for `pi-node-b`
1. Inspect the real host:
   - mounted filesystems
   - actual directories under `/srv`
   - bind mounts used by active services
   - backup paths
1. Compare documented paths with real paths.
1. Classify each mismatch:
   - docs stale, implementation correct
   - implementation drifted, docs stale
   - both wrong or confusing

## Remediation plan structure

After the audit, perform remediation in this order:

1. decide final directory layout
1. update docs to match intended layout
1. migrate one service at a time
1. validate data integrity and service health after each migration
1. only then remove obsolete paths or references

## Change safety rules

- Do not rename or move live data blindly.
- Do not perform multi-service path migrations in one step.
- Keep migrations incremental and reversible.
- Treat backups as part of the storage contract.

## Immediate rule for new work

Until this audit is completed:

- do not add new non-Prometheus services under `/srv/prometheus`

This is why the planned n8n deployment should use a dedicated path outside
`/srv/prometheus`.
