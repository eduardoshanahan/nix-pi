# Storage Directory Audit And Remediation Plan

Status: repo audit, host validation, and SMTP backup cleanup completed on March 10, 2026

## Problem statement

The repository had drifted into a mixed state:

- top-level documentation still described `/srv/prometheus` as a shared
  USB-backed application storage root
- current `pi-node-b` Nix configuration already uses dedicated `/srv/...`
  paths for several non-Prometheus services
- one remaining non-Prometheus implementation detail still wrote SMTP relay
  backups under `/srv/prometheus/backups/...`

That is undesirable because:

- the path name implies Prometheus ownership
- multiple unrelated services appear to depend on it
- documentation and implementation may have drifted
- future service placement decisions become harder when storage boundaries are
  unclear

## Why this audit was needed

Before introducing new services with persistent storage, we needed to verify:

1. what the documentation says
1. what is actually implemented on hosts
1. which uses are intentional
1. which uses should be migrated to dedicated paths

## Repo audit findings

The repo audit found the following state.

### Current implementation in `nixos/hosts/private/pi-node-b.nix`

- Prometheus:
  - `dataDir = "/srv/prometheus"`
- OwnTracks Recorder:
  - `dataDir = "/srv/owntracks"`
- TimeTagger:
  - `dataDir = "/srv/timetagger"`
- Home Assistant:
  - `dataDir = "/srv/home-assistant"`
- SMTP relay backups:
  - previously `backup_root="/srv/prometheus/backups/smtp-relay"`
  - remediated in this session to `backup_root="/srv/backups/smtp-relay"`

### Stale documentation found before remediation

- `README.md` documented:
  - OwnTracks at `/srv/prometheus/owntracks`
  - Home Assistant at `/srv/prometheus/home-assistant`
  - SMTP relay backups at `/srv/prometheus/backups/smtp-relay/...`
- `docs/plans/N8N_RPI_BOX_02_PHASE1_PLAN.md` already correctly treated
  `/srv/prometheus` as Prometheus-only and required n8n to use a dedicated
  path outside it

### Scope note

- The service README paths originally listed in the draft plan are not present
  in this repository checkout, so this audit could only verify the `nix-pi`
  repo content directly available here.

## Audit outcome

- `/srv/prometheus` should remain Prometheus-only.
- Non-Prometheus service state should use dedicated `/srv/...` paths.
- SMTP relay backups should live under `/srv/backups/...`, not under
  `/srv/prometheus/...`.

## Directory layout after repo remediation

Current intended layout:

- `/srv/prometheus` is reserved for Prometheus data only
- unrelated services move to dedicated paths such as:
  - `/srv/home-assistant`
  - `/srv/owntracks`
  - `/srv/timetagger`
  - `/srv/backups/smtp-relay`
  - `/srv/n8n`

This now matches both the repository intent and the validated live host state
on `pi-node-b`.

## Host validation completed

Validated on `pi-node-b` on March 10, 2026:

1. OwnTracks data is mounted from `/srv/owntracks`.
1. Home Assistant data is mounted from `/srv/home-assistant`.
1. `smtp-relay-backup.service` now writes to `/srv/backups/smtp-relay`.
1. Legacy SMTP backup directories from `/srv/prometheus/backups/smtp-relay`
   were migrated into `/srv/backups/smtp-relay`.
1. The empty legacy `/srv/prometheus/backups` tree was removed.

## Classification of mismatches found in repo

- `README.md`: docs stale, implementation already correct for OwnTracks and
  Home Assistant
- `README.md` plus SMTP relay backup script: both reflected a confusing shared
  storage layout and were remediated in this session
- `docs/plans/N8N_RPI_BOX_02_PHASE1_PLAN.md`: already aligned with the desired
  boundary

## Remediation sequence completed

Completed in this order:

1. validated the live host paths and mounts
1. deployed the updated SMTP backup root to `pi-node-b`
1. ran a manual SMTP backup successfully to the new location
1. migrated the remaining legacy backup directories into `/srv/backups/smtp-relay`
1. removed the empty obsolete directory tree under `/srv/prometheus/backups`

## Change safety rules

- Do not rename or move live data blindly.
- Do not perform multi-service path migrations in one step.
- Keep migrations incremental and reversible.
- Treat backups as part of the storage contract.

## Immediate rule for new work

For future work:

- do not add new non-Prometheus services under `/srv/prometheus`

This is why the planned n8n deployment should use a dedicated path outside
`/srv/prometheus`.
