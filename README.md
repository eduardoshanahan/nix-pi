# nix-pi

Provisioning and operating a small Raspberry Pi lab using NixOS flakes.

This repo builds SD card images for:

- Raspberry Pi 4 (aarch64)
- Raspberry Pi 3 (aarch64 by default, armv7l optional)

The public repo stays anonymized; environment-specific values (admin username,
SSH public keys, domains, IPs) live in gitignored private overrides.

## Public Repo Hygiene

Before commit/push, run the sanitization checklist in:

`PUBLIC_REPO_SANITIZATION_POLICY.md`

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

- `nix-services/documentation_unification_block_1.md`

Documentation sync gate for future changes:

- `../nix-services/DOC_SYNC_CHECKLIST.md`

Current host-runtime divergence register:

- `docs/HOST_RUNTIME_DIVERGENCES.md`

Current host-owned Uptime Kuma monitor policy:

- `docs/UPTIME_KUMA_MONITOR_POLICY.md`

## Table of Contents

- Docs index: `docs/README.md`
- Getting started: `docs/SETUP.md`
- Provisioning (build, flash, first boot): `docs/PROVISIONING.md`
- Secrets (sops-nix): `docs/SECRETS.md`
- Remote builds and signing: `docs/REMOTE_BUILDS.md`
- Host runtime divergences: `docs/HOST_RUNTIME_DIVERGENCES.md`
- Uptime Kuma monitor policy: `docs/UPTIME_KUMA_MONITOR_POLICY.md`
- Operations checks and service notes: `docs/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
- Documentation sync checklist: `../nix-services/DOC_SYNC_CHECKLIST.md`
- Private overrides (gitignored): `nixos/hosts/private/README.md`
- Local runbook (gitignored): `private/PROVISIONING_LOCAL.md`
- NixOS config layout:
  - Modules: `nixos/modules/`
  - Profiles: `nixos/profiles/`
- Application stacks (planned): `apps/README.md`
- Project records (decisions, work log, session prompt): `records/README.md`

## Quick build commands

Build images (including gitignored private overrides) from the repo root:

```bash
nix build path:.#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
nix build path:.#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

If you want local image files in this repo (for sync/backups), export them:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4 --decompress
scripts/export-sd-image result-rpi3 sd-image rpi3 --decompress
```

Deploy (host-local for `pi-node-a` / `pi-node-b`, remote builder for `pi-node-c`)

```bash
cd /home/eduardo/Programming/gitea.internal.example/hhlab-insfrastructure/nix-pi
nix flake update nix-services
git add flake.lock
git commit -m "flake: bump nix-services"
git push

nixos-rebuild switch \
  --flake path:.#pi-node-a \
  --target-host eduardo@pi-node-a \
  --build-host eduardo@pi-node-a \
  --sudo

nixos-rebuild switch \
  --flake path:.#pi-node-b \
  --target-host eduardo@pi-node-b \
  --build-host eduardo@pi-node-b \
  --sudo

nixos-rebuild switch \
  --flake path:.#pi-node-c \
  --target-host eduardo@pi-node-c \
  --build-host eduardo@pi-node-b \
  --sudo

ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub eduardo@<nas-fqdn>
```

Remote build note:

- `pi-node-c` builds on `pi-node-b` because `pi-node-c` does not have enough local build capacity.
- Cross-host Nix store copies require the builder to sign locally built paths and the target to trust the builder public key.
- In the current setup, `pi-node-b` signs with `/etc/nix/pi-node-b-priv.pem`, and `pi-node-c` trusts `pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=`.
- If the builder signing key changes or `pi-node-c` is rebuilt from scratch, re-establish target trust before using `--build-host eduardo@pi-node-b` again.

For bootstrap, expansion, and key rotation details, see `docs/REMOTE_BUILDS.md`.

## `pi-node-b` Storage Policy

- `pi-node-b` has two different storage classes:
  - SD card root filesystem at `/`
  - USB flash storage mounted at `/srv`
- Persistent service state on `pi-node-b` should be placed on the USB-backed `/srv` storage, not on the SD card.
- For new services, prefer dedicated paths such as `/srv/<service>` for application data and `/srv/backups/<service>` for backups.
- Do not place new long-lived application state under `/var/lib/...` on `pi-node-b` unless there is a specific reason it must stay on root.
- Docker on `pi-node-b` is configured to use `/srv/docker` as its data root, so image/layer storage also lives on the USB flash drive.
- Existing service docs in this README that reference `/srv/...` should be treated as following this policy, not as one-off exceptions.

## Monitoring Documentation Boundary

- This README owns host-specific runtime checks and operator quick commands for the currently deployed environment.
- Service-side monitoring architecture, module contracts, and constraints are canonical in `nix-services/monitoring_and_metrics_plan_prometheus_traefik.md` and `nix-services/services/*/README.md`.
- Host-managed monitor inventory and exceptions for `pi-node-b` are canonical in:
  - `docs/UPTIME_KUMA_MONITOR_POLICY.md`
  - `docs/HOST_RUNTIME_DIVERGENCES.md`
- Local docs index for this repo:
  - `docs/README.md`

## Operations Docs

- Host-specific quick checks and deployed-service notes now live in:
  - `docs/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
- Keep this README focused on repo boundaries, navigation, and canonical
  documentation ownership.
