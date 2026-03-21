# nix-pi

Provisioning and operating a small Raspberry Pi lab using NixOS flakes.

This repo builds SD card images for:

- Raspberry Pi 4 (aarch64)
- Raspberry Pi 3 (aarch64 by default, armv7l optional)

The public repo keeps a tracked placeholder private input, while the real
environment-specific values live in a sibling private companion repo:

- public repo: `nix-pi`
- private companion: `../nix-pi-private`
- tracked placeholder: `private-config-template/`
- override variable used by repo helpers: `NIX_PI_PRIVATE_FLAKE`

## Public Repo Hygiene

Before commit/push, run the sanitization checklist in:

`docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md`

## Housekeeping Reminder

- Added on 2026-03-06.
- Do housekeeping follow-up on 2026-03-10 (or later) after confirming stability:
  - Remove obsolete local sqlite files left from migrations (for example old Grafana/Kuma DB files).
  - Keep current backup snapshots for at least a few more days before deleting any historical copies.
  - Re-check service health and alert noise after the recent database centralization changes.

## Why This Project

I tried to implement this using Ubuntu, which I have been using for years, and tried to base projects on devcontainers.

The theory was good, but the implementation was a source of frustration. The aim was to have a starting project with Git as a base and add extra tools as needed, but each project started drifting as soon as I started another one, and the attempts to synchronize them were too time consuming.

For this experiment, I decided to try NixOS, which is brand new for me, because I heard [Geoffrey Huntley](https://ghuntley.com/) talking about it.

Also, because it is a brand new thing for me, I used it as a way to learn based on the conversations with Codex.

So far it seems a lot more solid: working in a `nix develop` shell is a lot less problematic than with devcontainers, and after a few days of discontinuous work I managed to have the Raspberry Pis working as expected, with minimal intervention from my part (just flashing cards and powering up).

The next step would be to add some applications, and things might change at that point, but right now I am very happy with the results.

## Documentation Ownership

To avoid duplication and contradictions with `nix-services`, docs are split by responsibility:

- `nix-pi` owns host lifecycle docs: setup, provisioning, flashing, bootstrap, rebuild commands, and SOPS host provisioning.
- `nix-services` owns service lifecycle docs: module options/behavior, Compose + systemd runtime patterns, and service runbooks.

Current-state rule:

- Services are already deployed and stable. Deployment plans should be treated as rebuild/disaster-recovery/expansion references unless a new rollout is explicitly requested.

For the ownership baseline and contradiction register, see:

- `../nix-services/records/documentation_unification_block_1.md`

Documentation sync gate for future changes:

- `../nix-services/docs/policy/DOC_SYNC_CHECKLIST.md`

Current host-runtime divergence register:

- `docs/policy/HOST_RUNTIME_DIVERGENCES.md`

Current host-owned Uptime Kuma monitor policy:

- `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`

## Documentation Index

- Documentation index: `DOCUMENTATION_INDEX.md`
- Docs layout: `docs/README.md`
- Getting started: `docs/lifecycle/SETUP.md`
- Provisioning (build, flash, first boot): `docs/lifecycle/PROVISIONING.md`
- Secrets (sops-nix): `docs/lifecycle/SECRETS.md`
- Remote builds and signing: `docs/lifecycle/REMOTE_BUILDS.md`
- Host runtime divergences: `docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- Uptime Kuma monitor policy: `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
- Operations checks and service notes: `../nix-pi-private/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
- Plans and audits: `docs/plans/`
- Recovery docs: `docs/recovery/`
- Continuity notes: `docs/continuity/`
- Documentation sync checklist: `../nix-services/docs/policy/DOC_SYNC_CHECKLIST.md`
- Private companion contract: `nixos/hosts/private/README.md`
- Local runbook (gitignored): `private/PROVISIONING_LOCAL.md`
- NixOS config layout:
  - Modules: `nixos/modules/`
  - Profiles: `nixos/profiles/`
- Application stacks (planned): `apps/README.md`
- Project records (decisions, work log, session prompt): `records/README.md`

## Private Config Workflow

Private values are now expected from a sibling flake:

- `../nix-pi-private`

The tracked placeholder contract lives in:

- `private-config-template/`

The repo has explicit preflight helpers for the private input:

- `nix run "path:$PWD#validate-private-config" -- pi-node-a`
- `nix run "path:$PWD#validate-pi-host" -- pi-node-a`

By default the helpers look for `../nix-pi-private`.
If your private flake lives elsewhere, set:

- `NIX_PI_PRIVATE_FLAKE=/absolute/path/to/nix-pi-private`

If you also need to validate against a local sibling `nix-services` checkout
instead of the locked remote input, set:

- `NIX_PI_NIX_SERVICES_FLAKE=/absolute/path/to/nix-services`

For direct `nix build` or `nixos-rebuild` commands, pass the private flake
explicitly with `--override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"`.

## Quick build commands

Build images with the real private flake from the repo root:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nix run "path:$PWD#validate-private-config" -- pi-node-a
nix build --override-input private "path:$NIX_PI_PRIVATE_FLAKE" path:$PWD#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
nix build --override-input private "path:$NIX_PI_PRIVATE_FLAKE" path:$PWD#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

If you want local image files in this repo (for sync/backups), export them:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4 --decompress
scripts/export-sd-image result-rpi3 sd-image rpi3 --decompress
```

Deploy one host at a time (host-local for `pi-node-a` / `pi-node-b`, remote builder for `pi-node-c`)

```bash
cd /absolute/path/to/nix-pi
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nix run "path:$PWD#validate-pi-host" -- pi-node-a
nix run "path:$PWD#validate-pi-host" -- pi-node-b
nix run "path:$PWD#validate-pi-host" -- pi-node-c
nix flake update nix-services
git add flake.lock
git commit -m "flake: bump nix-services"
git push

nixos-rebuild switch \
  --flake path:$PWD#pi-node-a \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --target-host eduardo@pi-node-a \
  --build-host eduardo@pi-node-a \
  --sudo

nixos-rebuild switch \
  --flake path:$PWD#pi-node-b \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --target-host eduardo@pi-node-b \
  --build-host eduardo@pi-node-b \
  --sudo

nixos-rebuild switch \
  --flake path:$PWD#pi-node-c \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --target-host eduardo@pi-node-c \
  --build-host eduardo@pi-node-b \
  --sudo

ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub eduardo@<nas-fqdn>
```

Remote build note:

- `pi-node-c` builds on `pi-node-b` because `pi-node-c` does not have enough local build capacity.
- Cross-host Nix store copies require the builder to sign locally built paths and the target to trust the builder public key.
- In the current setup, the designated builder signs with its host-local key,
  and target nodes trust the matching public key string declared in the private
  companion config.
- If the builder signing key changes or `pi-node-c` is rebuilt from scratch, re-establish target trust before using `--build-host eduardo@pi-node-b` again.
- Keep rebuilds one host at a time so any migration mistake is isolated to a
  single box.

For bootstrap, expansion, and key rotation details, see `docs/lifecycle/REMOTE_BUILDS.md`.

## `pi-node-b` Storage Policy

- `pi-node-b` has two different storage classes:
  - SD card root filesystem at `/`
  - USB flash storage mounted at `/srv`
- Persistent service state on `pi-node-b` should be placed on the USB-backed `/srv` storage, not on the SD card.
- For new services, prefer dedicated paths such as `/srv/<service>` for application data and `/srv/backups/<service>` for backups.
- Do not place new long-lived application state under `/var/lib/...` on `pi-node-b` unless there is a specific reason it must stay on root.
- Docker on `pi-node-b` is configured to use `/srv/docker` as its data root, so image/layer storage also lives on the USB flash drive.
- Existing service docs in this README that reference `/srv/...` should be treated as following this policy, not as one-off exceptions.

## `pi-node-c` Storage Policy

- `pi-node-c` has two different storage classes:
  - SD card root filesystem at `/`
  - external disk mounted at `/srv`
- Persistent service state on `pi-node-c` should be placed on the external-disk-backed `/srv` storage, not on the SD card.
- Docker on `pi-node-c` is configured to use `/srv/docker` as its data root, so image/layer storage and named volumes should live on the external disk.
- Loki state should live under `/srv/loki`, with backups under `/srv/backups/loki`.
- Host-local sync and log-shipper state should also prefer `/srv/...` paths on this host when practical.

## Boundary Reminder

- This README owns repo overview, host-lifecycle boundaries, and documentation
  pointers.
- Service-side monitoring architecture, module contracts, and constraints are
  canonical in `nix-services/monitoring_and_metrics_plan_prometheus_traefik.md`
  and `nix-services/services/*/README.md`.
- Host-managed monitor inventory and exceptions for `pi-node-b` are canonical
  in:
  - `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
  - `docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- Local documentation index for this repo:
  - `DOCUMENTATION_INDEX.md`

## Operations Docs

- Host-specific operator quick checks and deployed-service notes live in:
  - `docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
- Keep this README focused on repo boundaries, navigation, and canonical
  documentation ownership.
