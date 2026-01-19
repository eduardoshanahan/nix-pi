# nix-pi

NixOS configuration for a small Raspberry Pi fleet, managed from a workstation.

Principles:

- NixOS config is edited locally and deployed remotely
- No manual “fixes” on Pis after bootstrap
- Applications run in Docker

## Documentation index

- Getting started (Ubuntu + flakes): `documentation/getting nix ready.md`
- Step-by-step end-to-end plan: `documentation/raspberry_pi_nix_os_project_plan.md`
- Build SD images on Ubuntu x86_64 (QEMU/binfmt): `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md`
- Deployment workflow and design notes: `documentation/DEPLOYMENT.md`
- Runbooks (operational procedures): `documentation/runbooks/README.md`
- Current host ↔ IP mapping: `documentation/ip-addresses.md`
- Security / what not to commit: `documentation/security.md`
- Project context / architecture notes: `documentation/context_for_codex_nix_os_raspberry_pi_fleet_project.md`
- Architecture decisions:
  - `documentation/adr/ADR-0001-record-architecture-decisions.md`
  - `documentation/adr/ADR-0002-fleet-operations-documentation.md`
- Change log / diary (create entries): `documentation/diary/README.md`

## Repo layout

- `flake.nix`: fleet entrypoint
- `modules/`: shared NixOS modules
- `hosts/`: per-Pi configuration (and hardware config)
- `scripts/`: deployment helpers

## Quickstart (per Pi)

1. Bootstrap: build + flash a custom SD image with SSH keys baked in (see `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md:1` and `documentation/raspberry_pi_nix_os_project_plan.md:1`).
2. Ensure the Pi is reachable from your workstation (recommended: DHCP reservation; initially deploy by IP, later by DNS when Pi-hole is up).
3. Pull hardware config into the repo:
   - `./scripts/pull-hardware rpi-box-01 root@<pi-ip>`
4. Deploy:
   - `./scripts/deploy rpi-box-01 root@<pi-ip>`

More detail: `documentation/DEPLOYMENT.md`.
