# Session Prompt

Last updated: 2026-01-22

## Current State

- Repo contains `records/`, `docs/`, `flake.nix`, `flake.lock`, `.gitignore`,
  and `.pre-commit-config.yaml`.
- Git repo initialized locally.
- NixOS provisioning structure under `nixos/` with RPi3/4 profiles and modules.
- Flake includes `nixos-hardware` for Raspberry Pi modules.
- Record-keeping structure initialized (decisions, work log, questions, session
  prompt, risks, milestones, changelog).
- ADRs live in `records/architecture-decisions/` (one file per decision).
- ADR review cadence is set: per major change and at start of each working
  session.
- Nix dev shell is defined via `flake.nix`; onboarding guide in `docs/SETUP.md`.
- Confidentiality guidance and Git hygiene defaults added; see
  `docs/CONFIDENTIALITY.md`.
- `prek` is included for pre-commit checks with a gitleaks secrets scan.
- Markdown linting added to pre-commit hooks via markdownlint-cli2.
- Setup docs explain why `prek install` is manual.
- Setup docs include a first-time checklist.
- Pi fleet requirements captured: admin+per-node users, Ethernet-only, hostnames.
- Admin user is configurable via private overrides; SSH access is configured via
  `/etc/ssh/authorized_keys/%u`.
- Provisioning docs added for SD image builds and SSH access.
- `docs/PROVISIONING.md` is the primary guide for imaging and first boot.
- Provisioning guide includes QEMU/binfmt setup for x86 hosts.
- Provisioning guide includes troubleshooting for cross-arch builds.
- Repo defaults are anonymized; private overrides live in
  `nixos/hosts/private/`.
- Confidentiality docs mention private overrides path.
- Private per-host overrides are supported via `nixos/hosts/private/*.nix`.
- Private hostnames can be set via per-host overrides if needed, but the primary
  workflow uses generic images and sets hostnames after first boot.
- Public per-host hostnames/configs are not kept in Git; see anonymized examples.
- `/etc/ssh/authorized_keys` directory created via tmpfiles rule.
- Preferred workflow embeds admin public key(s) into the image via
  `lab.adminAuthorizedKeys` (private override) so SD cards do not require
  post-flash edits.
- Cross-arch builds require `extra-platforms` in Nix config.
- Pi profiles disable `hardware.enableAllHardware` to avoid module shrink errors.
- Primary workflow builds two images (Pi 4 aarch64, Pi 3 aarch64) and sets
  hostnames after first boot.
- Pi 3 defaults to aarch64 for better cache coverage and build speed on x86.

## Decisions (active)

- Records live under `records/` at repo root. See records/DECISIONS.md.

## Recent Work

- Created baseline record files and templates. See records/WORKLOG.md.
- Added risk, milestone, changelog, and ADR tracking. See records/WORKLOG.md.
- Added flake-based dev shell and setup guide. See records/WORKLOG.md.
- Added confidentiality guide, `.gitignore`, milestones, and risks. See
  records/WORKLOG.md.
- Added prek and secrets scanning. See records/WORKLOG.md.
- Added markdown linting to pre-commit hooks. See records/WORKLOG.md.
- Initialized Git, fixed gitleaks args, and resolved markdownlint warnings. See
  records/WORKLOG.md.

## Open Questions

- ADR review cadence confirmed. See records/QUESTIONS.md.

## Next Steps

- If approved, keep appending entries as work proceeds.
- Capture project goals and initial plan once provided.
- Build SD images and flash cards.

## Prompt to Resume

You are helping in ~/Programming/nix-pi-2. Continue maintaining project records
in `records/`. Review `records/DECISIONS.md`, `records/WORKLOG.md`, and
`records/QUESTIONS.md` for context. At session start, read all text files in the
workspace (tracked and untracked, including private/secrets), excluding `.git`
and binaries, before proceeding.

## Resume Checklist

- Read all text files in the workspace (tracked and untracked, including
  private/secrets), excluding `.git` and binaries.
- Ensure private overrides are set (gitignored):
  - `nixos/hosts/private/overrides.nix` (see `nixos/hosts/private/README.md`)
  - Set `lab.adminUser` and `lab.adminAuthorizedKeys` for fully automated SSH.
- Build the Pi 4 image (aarch64) with private overrides included:
  `nix build path:.#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4`
- Build the Pi 3 image (aarch64) with private overrides included:
  `nix build path:.#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3`
- Optional: for Pi 3 armv7l builds, use:
  `NIXPKGS_ALLOW_BROKEN=1 nix build --impure path:.#nixosConfigurations.rpi3-armv7l.config.system.build.sdImage -o result-rpi3`
  and ensure `/etc/nix/nix.conf` includes `gccarch-armv7-a` in `system-features`.
- Flash SD cards per `docs/PROVISIONING.md`.
- If `lab.adminAuthorizedKeys` is not set, inject the key onto the SD card as a
  fallback (see `docs/PROVISIONING.md`).
