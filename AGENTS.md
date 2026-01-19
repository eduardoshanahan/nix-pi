# Agent notes (nix-pi)

This file is guidance for coding assistants working in this repo.

## What this repo is

- NixOS configuration for a small Raspberry Pi fleet.
- **Single source of truth:** root `flake.nix` + `hosts/` + `modules/`.
- SD images are built from this repo (not downloaded), so SSH works on first boot.

## Key build targets

Build SD images:

- `rpi-box-03`: `nix build .#nixosConfigurations.rpi-box-03-sd.config.system.build.sdImage`
- `rpi-box-01`: `nix build .#nixosConfigurations.rpi-box-01-sd.config.system.build.sdImage`

Notes:

- Outputs are under `./result/sd-image/` (usually `*.img.zst`).
- `./result` points into `/nix/store` (read-only). Decompress via streaming:
  - `mkdir -p ./out`
  - `zstd -d -c ./result/sd-image/*.img.zst > ./out/nixos-sd-image.img`

## Ubuntu x86_64 builds (aarch64 via QEMU)

If building `aarch64-linux` images on an x86_64 Ubuntu host:

- Install QEMU/binfmt: `sudo apt install -y qemu-user-static binfmt-support`
- Ensure Nix daemon allows aarch64 builds in `/etc/nix/nix.conf`:
  - `extra-platforms = aarch64-linux ...`
  - `trusted-users = root <username>`
  - Recommended: `sandbox = false`

Full walkthrough lives in `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md`.

## Files to edit for first-boot SSH

Create `local/authorized-keys.nix` from the example and add your real public keys:

- `local/authorized-keys.nix.example` → `local/authorized-keys.nix`

Make sure:

- `services.openssh` is enabled (via `modules/common.nix`)
- `local/authorized-keys.nix` contains the correct key(s) for `root` and `pi`

Keep each key string as a single line (no embedded newline).

## Hardware config workflow

Each Pi has a `hosts/rpi-box-NN/hardware-configuration.nix` file (initially empty placeholder).

After first boot + SSH:

- Pull real hardware config into the repo:
  - `./scripts/pull-hardware rpi-box-01 root@<pi-ip>`

Those files are imported by each `hosts/rpi-box-NN/default.nix` and used for subsequent deploys.

## Deployment workflow (after bootstrap)

- Deploy from workstation:
  - `./scripts/deploy rpi-box-01 root@<pi-ip>`
- The deploy script uses the root flake target `.#<host>` and can build locally or on the target depending on script/env settings.

## Conventions

- Prefer minimal, targeted changes; avoid introducing a second build track.
- Keep documentation consistent with the root-flake workflow.
- When adding a new Pi:
  - Create `hosts/rpi-box-NN/{default.nix,hardware-configuration.nix,sd-image.nix}`
  - Add `rpi-box-NN` and `rpi-box-NN-sd` to root `flake.nix`.
