# Session Prompt

Last updated: 2026-01-20

## Current State

- Repo contains `records/`, `docs/`, `flake.nix`, `flake.lock`, `.gitignore`,
  and `.pre-commit-config.yaml`.
- Git repo initialized locally.
- NixOS provisioning structure under `nixos/` with RPi3/4 profiles and hosts.
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
- Admin user `admin` will be in `docker` group; public key added manually at
  imaging time; repo synced via a file sync tool.
- Provisioning docs added for SD image builds and SSH key injection.
- `docs/PROVISIONING.md` is the primary guide for imaging and first boot.
- Provisioning guide includes QEMU/binfmt setup for x86 hosts.
- Provisioning guide includes troubleshooting for cross-arch builds.
- Repo defaults are anonymized; private overrides live in
  `nixos/hosts/private/`.
- Confidentiality docs mention private overrides path.
- Private per-host overrides are supported via `nixos/hosts/private/*.nix`.
- Private hostnames set for rpi-box nodes in private overrides.
- RPi boot loader settings removed (deprecated); admin SSH key file required.
- `/etc/ssh/authorized_keys` directory created via tmpfiles rule.
- Build allows empty SSH keys; manual key injection remains required.
- Cross-arch builds require `extra-platforms` in Nix config.
- Pi profiles disable `hardware.enableAllHardware` to avoid module shrink errors.

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

- Confirm or adjust the `records/` structure and files. See
  records/QUESTIONS.md.
- ADR review cadence confirmed. See records/QUESTIONS.md.

## Next Steps

- If approved, keep appending entries as work proceeds.
- Capture project goals and initial plan once provided.
- Build SD images per host and flash cards.

## Prompt to Resume

You are helping in ~/Programming/nix-pi-2. Continue maintaining project records
in `records/`. Review `records/DECISIONS.md`, `records/WORKLOG.md`, and
`records/QUESTIONS.md` for context. Ask the user to confirm the records
structure if not answered, then proceed with project planning.
