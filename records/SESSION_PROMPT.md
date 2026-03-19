# Session Prompt

Last updated: 2026-03-19

## Current State

- `pi-node-c` now runs Pi-hole, Pi-hole exporter, and scheduled Pi-hole sync
  from `pi-node-a`.
- Host-managed monitoring and Homepage inventory on `pi-node-b` include the
  `pi-node-c` Pi-hole surfaces.
- `pi-node-c` now mounts the external disk at `/srv`.
- `pi-node-c` Docker data root is active at `/srv/docker`.
- `pi-node-c` Loki, Promtail, and Pi-hole sync state now prefer `/srv/...`
  paths on the external disk.
- The stale SD-card `/var/lib/docker` copy on `pi-node-c` has been removed.
- Current SD-card root usage on `pi-node-c` is about `4.4G`, with remaining
  routine usage mainly in `/nix/store`, journald, and normal `/var` state.
- `/nix` migration on `pi-node-c` has been investigated and intentionally
  deferred until a console recovery path is available.
- Remote rebuilds for `pi-node-c` still use `pi-node-b` as build host.
- Some `pi-node-c` remote rebuilds still need manual recursive signing of the
  built closure on `pi-node-b` before cross-host `nix copy` succeeds.

## Decisions (active)

- Keep `pi-node-c` on an external-disk-backed `/srv` layout for now.
- Defer `/nix` migration on `pi-node-c` until there is a direct recovery path.
- Treat `pi-node-c` as an additional synced Pi-hole resolver for now rather
  than renaming the existing primary/secondary labels immediately.

## Recent Work

- Added Pi-hole, Pi-hole exporter, and Pi-hole sync on `pi-node-c`.
- Added `pi-node-c` Pi-hole inventory to host-managed monitoring/docs.
- Migrated `pi-node-c` service state from the SD card to the external disk by
  remounting the disk at `/srv`.
- Removed the stale SD-card Docker tree from `/var/lib/docker` on `pi-node-c`.
- Investigated `/nix` migration and documented why it is deferred for now.

## Open Questions

- Whether `pi-node-c` should later become the preferred DNS source for the lab.
- Whether the Pi-hole primary/secondary labels should be renamed if DNS
  preference moves toward `pi-node-c`.

## Next Steps

- Keep `pi-node-c` under observation on the new `/srv` layout.
- If desired later, plan a separate `/nix` migration session for `pi-node-c`
  only after a direct recovery path is available.
- If desired later, decide whether `pi-node-c` should become the preferred DNS
  source and whether the primary/secondary Pi-hole labels should be renamed.

## Prompt to Resume

You are helping in `nix-pi`. Continue maintaining project records in
`records/`. Review `records/DECISIONS.md`, `records/WORKLOG.md`, and
`records/QUESTIONS.md` for context. `pi-node-c` now runs Pi-hole and uses the
external disk as `/srv`; `/nix` on that host is still on the SD card and should
not be migrated without a console recovery path.

## Resume Checklist

- Read the current host docs and records before changing live hosts.
- For `pi-node-c`, remember:
  - `/srv` is on the external disk
  - Docker uses `/srv/docker`
  - `/nix` is still on the SD card
  - `/nix` migration is deferred pending console access
- If remote-building `pi-node-c` from `pi-node-b` fails on unsigned paths,
  inspect the built closure on `pi-node-b` and sign it recursively before
  retrying the deploy.
