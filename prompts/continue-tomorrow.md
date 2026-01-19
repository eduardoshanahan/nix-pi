# Continue tomorrow (nix-pi)

You are helping with a NixOS Raspberry Pi fleet repo.

## Goal

Continue configuring and deploying a small Pi fleet from a workstation, keeping the repo safe to publish publicly.

## Repo shape (current)

- Root flake defines:
  - `nixosConfigurations`: `pi-node-a`, `pi-node-b`, `pi-node-c`, plus SD image targets `pi-node-a-sd` (Pi 4) and `pi-node-c-sd` (Pi 3)
  - `devShells`: workstation tooling via `nix develop`
- Hosts:
  - `pi-node-a` and `pi-node-b` are Raspberry Pi 4
  - `pi-node-c` is Raspberry Pi 3
- Shared modules: `modules/common.nix`, `modules/networking.nix`, `modules/docker.nix`, plus `modules/hardware/rpi-3.nix` and `modules/hardware/rpi-4.nix`
- Runbooks + ADRs + diary live under `documentation/`

## Important local-only files (not committed)

Before deploying/building SD images, ensure these exist locally:

1) `local/authorized-keys.nix`
   - Copy from `local/authorized-keys.nix.example`
   - Put real SSH public keys for `root` and `pi` there
   - This file is ignored by git

2) `documentation/ip-addresses.local.md` (optional)
   - Copy from `documentation/ip-addresses.md`
   - Put real LAN IP mapping there
   - Ignored by git

## Known current state

- The physical machines are reachable by SSH as `root` (IPs are stored locally, not in git).
- The machines’ current hostnames may still be `pi-3`/`pi-4` (not yet deployed to switch to `rpi-box-*`).

## Suggested next steps

1) Create/update `local/authorized-keys.nix` (if missing).
2) For each box:
   - Run `./scripts/pull-hardware <host> root@<ip>` to capture real `hardware-configuration.nix`
   - Run `./scripts/deploy <host> root@<ip>` to apply the configuration and set `networking.hostName`
3) Verify:
   - `hostname`, `cat /etc/hostname`
   - `nixos-version`
   - `systemctl is-system-running`
4) Record the work:
   - Add a diary entry in `documentation/diary/yyyy-mm-dd.md` with boxes affected, commands, and verification.

## Constraints / conventions

- Keep changes minimal and targeted.
- Keep secrets and LAN specifics out of git (see `documentation/security.md`).
- Prefer runbooks for repeatable procedures; use ADRs for decisions.

