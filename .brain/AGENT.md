# Agent Instructions — nix-pi (public)

This file extends the global instructions at `~/Programming/hhlab/brain/.brain/AGENT.md`.

---

## Project Context

- **BRAIN_CONTEXT**: raspberry-pi
- **BRAIN_REPO**: nix-pi
- **Purpose**: Host-ownership layer of the homelab. Owns RPi NixOS flake outputs, SD-image workflows, base host modules, SOPS provisioning, host selection and wiring for services from nix-services.
- **Private counterpart**: `../nix-pi-private/` (never pushed to GitHub)

---

## Public Brain Rules

- This .brain/ directory is pushed to Gitea — never add sensitive content here
- This directory only contains content explicitly published via `brainctl publish`
- Raw investigations live in `../nix-pi-private/.brain/` — BRAIN_ROOT points there

---

## Ownership Boundary

Use `nix-pi` for:

- host lifecycle
- image builds and flashing workflows
- users, SSH, networking, Docker enablement
- SOPS and host bootstrap material
- host-specific service enablement and wiring
- host-specific runtime divergence from shared service modules
- host-owned monitoring inventory and operator docs

Use `nix-services` for:

- shared service module behavior
- service options/contracts
- generated compose/systemd patterns
- service READMEs and service-side runbooks

Rule: if the change is a reusable service behavior change, it belongs in `nix-services`, not here.

---

## Start Here

When working in `nix-pi`, read in this order:

1. `README.md`
2. `DOCUMENTATION_INDEX.md`
3. `docs/README.md`
4. the specific doc for the task (see `docs/setup/`, `docs/operations/`, `docs/recovery/`, `docs/decisions/`)
5. relevant implementation files in `flake.nix`, `nixos/modules/`, `nixos/profiles/`, `nixos/hosts/`, `../nix-pi-private/modules/`

If a pointer doc exists here and points to `nix-services`, follow the pointer instead of duplicating policy locally.

---

## Repo Structure

- `flake.nix`: flake inputs, NixOS outputs, dev shell
- `nixos/modules/`: common host primitives
- `nixos/profiles/`: RPi image profiles
- `nixos/hosts/`: public host entry modules
- `scripts/`: operational helper scripts
- `docs/`: human-facing docs (setup/, operations/, recovery/, decisions/)
- `DOCUMENTATION_INDEX.md`: quick navigation index
- `secrets/`: SOPS-encrypted secret files safe to commit
- `../nix-pi-private/`: private companion (real env values, modules, continuity notes)

---

## Host Inventory

### `rpi-box-01`

- Pi-hole primary
- Traefik, Promtail, cAdvisor, Tailscale, Docker socket proxy
- static LAN addressing and internal DNS preference
- SSD-backed `/srv` storage

### `rpi-box-02`

- main app and monitoring hub
- SSD-backed `/srv`, NFS media mount at `/mnt/media`
- large host-specific config in `../nix-pi-private/modules/rpi-box-02.nix`
- host-managed Uptime Kuma monitor inventory
- intentional Homepage Docker inventory override
- intentional Ghost compose override for SMTP TLS behavior

---

## Working Rules

- Run `brainctl preflight "<task>"` before meaningful implementation work
- Use `nix run "path:$PWD#validate-private-config" -- <host>` before builds or rebuilds
- For `nix build` and `nixos-rebuild`, pass `--override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"`
- Never put plaintext secrets in Git
- Decrypted secrets must only appear at runtime under `/run/secrets`
- `lab.sops.ageKeyFile` must point to a host file, never a Nix store path
- Commit via `nix develop --command git commit` — pre-commit hooks need dev shell tools
- Never use `--no-verify` — enter `nix develop` and rerun instead

---

## Build / Deploy Norms

- SD image outputs defined for `rpi4`, `rpi3`, optional `rpi3-armv7l`
- Host outputs: `rpi-box-01`, `rpi-box-02`
- If a task touches remote builds or signing, update `docs/operations/REMOTE_BUILDS.md`
- If a task changes provisioning expectations, update `docs/setup/PROVISIONING.md` and/or `docs/setup/SECRETS.md`

---

## Documentation Sync Rules

When you change behavior, update the owning docs in the same change:

- host runtime divergence changes → `docs/operations/HOST_RUNTIME_DIVERGENCES.md`
- Uptime Kuma host-managed monitor changes → `docs/operations/UPTIME_KUMA_MONITOR_POLICY.md`
- provisioning/bootstrap changes → `docs/setup/PROVISIONING.md`, `docs/setup/SECRETS.md`, or `docs/operations/REMOTE_BUILDS.md`
- storage-policy changes on `rpi-box-02` → `README.md` and `docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`

---

## Scripts

Use existing helpers instead of ad hoc commands:

- `scripts/export-sd-image`
- `scripts/inject-ssh-key`
- `scripts/bootstrap-sops-age-key`
- `scripts/bootstrap-nix-signing-key`

---

## Session Continuity

Check at session start:

- `.brain/INDEX.md`
- `.brain/investigations/` (most recent files)

Prefer appending new entries over rewriting historical ones.

---

## Avoid

- duplicating shared service logic from `nix-services`
- committing plaintext secrets or private identifiers
- assuming `nix build .#...` picks up the private companion flake automatically
- editing host runtime behavior without updating the owning docs
- treating `../nix-pi-private` as throwaway
