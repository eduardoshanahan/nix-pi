# Session Prompt

Last updated: 2026-03-19

## Current State

- `rpi-box-03` now runs Pi-hole, Pi-hole exporter, and scheduled Pi-hole sync
  from `rpi-box-01`.
- Host-managed monitoring and Homepage inventory on `rpi-box-02` include the
  `rpi-box-03` Pi-hole surfaces.
- `rpi-box-03` now mounts the external disk at `/srv`.
- `rpi-box-03` Docker data root is active at `/srv/docker`.
- `rpi-box-03` Loki, Promtail, and Pi-hole sync state now prefer `/srv/...`
  paths on the external disk.
- The stale SD-card `/var/lib/docker` copy on `rpi-box-03` has been removed.
- Current SD-card root usage on `rpi-box-03` is about `4.4G`, with remaining
  routine usage mainly in `/nix/store`, journald, and normal `/var` state.
- `/nix` migration on `rpi-box-03` has been investigated and intentionally
  deferred until a console recovery path is available.
- Remote rebuilds for `rpi-box-03` still use `rpi-box-02` as build host.
- Some `rpi-box-03` remote rebuilds still need manual recursive signing of the
  built closure on `rpi-box-02` before cross-host `nix copy` succeeds.

## Decisions (active)

- Keep `rpi-box-03` on an external-disk-backed `/srv` layout for now.
- Defer `/nix` migration on `rpi-box-03` until there is a direct recovery path.
- Treat `rpi-box-03` as an additional synced Pi-hole resolver for now rather
  than renaming the existing primary/secondary labels immediately.

## Recent Work

- Added Pi-hole, Pi-hole exporter, and Pi-hole sync on `rpi-box-03`.
- Added `rpi-box-03` Pi-hole inventory to host-managed monitoring/docs.
- Migrated `rpi-box-03` service state from the SD card to the external disk by
  remounting the disk at `/srv`.
- Removed the stale SD-card Docker tree from `/var/lib/docker` on `rpi-box-03`.
- Investigated `/nix` migration and documented why it is deferred for now.

## Open Questions

- Whether `rpi-box-03` should later become the preferred DNS source for the lab.
- Whether the Pi-hole primary/secondary labels should be renamed if DNS
  preference moves toward `rpi-box-03`.

## Next Steps

- Keep `rpi-box-03` under observation on the new `/srv` layout.
- If desired later, plan a separate `/nix` migration session for `rpi-box-03`
  only after a direct recovery path is available.
- If desired later, decide whether `rpi-box-03` should become the preferred DNS
  source and whether the primary/secondary Pi-hole labels should be renamed.

## Prompt to Resume

You are helping in `nix-pi`. Continue maintaining project records in
`records/`. Review `records/DECISIONS.md`, `records/WORKLOG.md`, and
`records/QUESTIONS.md` for context. `rpi-box-03` now runs Pi-hole and uses the
external disk as `/srv`; `/nix` on that host is still on the SD card and should
not be migrated without a console recovery path.

## Resume Checklist

- Read the current host docs and records before changing live hosts.
- For `rpi-box-03`, remember:
  - `/srv` is on the external disk
  - Docker uses `/srv/docker`
  - `/nix` is still on the SD card
  - `/nix` migration is deferred pending console access
- If remote-building `rpi-box-03` from `rpi-box-02` fails on unsigned paths,
  inspect the built closure on `rpi-box-02` and sign it recursively before
  retrying the deploy.
