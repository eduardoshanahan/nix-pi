# Changelog

Format

- Date: YYYY-MM-DD
- Change: short summary
- Details: brief notes
- References: optional links/paths

---

- Date: 2026-01-20
- Change: Initialized project record-keeping files.
- Details: Added decisions, work log, questions, session prompt, and supporting
  structure.
- References: records/README.md

- Date: 2026-01-20
- Change: Added risks, milestones, changelog, and ADR tracking.
- Details: Created logs and `records/architecture-decisions/` with a per-decision
  template.
- References: records/RISKS.md, records/MILESTONES.md,
  records/architecture-decisions/README.md

- Date: 2026-01-20
- Change: Set ADR review cadence.
- Details: Reviews occur per major change and at the start of each working
  session.
- References: records/DECISIONS.md, records/QUESTIONS.md

- Date: 2026-01-20
- Change: Added flake-based dev shell and setup guide.
- Details: Introduced `flake.nix` and documented onboarding; added ADR for
  flakes decision.
- References: flake.nix, docs/SETUP.md,
  records/architecture-decisions/0001-use-nix-flakes.md

- Date: 2026-01-20
- Change: Added confidentiality guidance and Git hygiene.
- Details: Added `.gitignore`, confidentiality guide, milestones, and risks.
- References: docs/CONFIDENTIALITY.md, .gitignore, records/MILESTONES.md,
  records/RISKS.md

- Date: 2026-01-20
- Change: Added prek and secrets scanning.
- Details: Added `prek`/`gitleaks` to the dev shell and created
  `.pre-commit-config.yaml`.
- References: flake.nix, .pre-commit-config.yaml, docs/SETUP.md,
  records/architecture-decisions/0002-use-prek-and-gitleaks.md

- Date: 2026-01-20
- Change: Added markdown linting to pre-commit hooks.
- Details: Added markdownlint-cli2 hook for `.md` files.
- References: .pre-commit-config.yaml

- Date: 2026-01-20
- Change: Generated `flake.lock`.
- Details: `nix develop` created the flake lockfile during pre-commit check
  attempt.
- References: flake.lock

- Date: 2026-01-20
- Change: Fixed pre-commit config and markdown formatting.
- Details: Updated gitleaks args and resolved markdownlint warnings across docs
  and records.
- References: .pre-commit-config.yaml, docs/SETUP.md, records/CHANGELOG.md

- Date: 2026-01-20
- Change: Clarified why `prek install` is manual.
- Details: Documented that `nix develop` does not write git hooks.
- References: docs/SETUP.md

- Date: 2026-01-20
- Change: Added first-time setup checklist.
- Details: Added a short onboarding checklist to setup docs.
- References: docs/SETUP.md

- Date: 2026-01-20
- Change: Added NixOS provisioning structure for Raspberry Pi fleet.
- Details: Added flake outputs, NixOS modules, profiles, and provisioning docs.
- References: flake.nix, nixos/modules/options.nix, docs/PROVISIONING.md

- Date: 2026-01-20
- Change: Updated flake inputs for NixOS hardware support.
- Details: Added `nixos-hardware` input for Raspberry Pi profiles.
- References: flake.nix, flake.lock

- Date: 2026-01-20
- Change: Linked provisioning docs from setup guide.
- Details: Added a pointer to `docs/PROVISIONING.md`.
- References: docs/SETUP.md

- Date: 2026-01-20
- Change: Anonymized repo defaults and added private overrides.
- Details: Replaced personal identifiers with placeholders and added a private
  overrides path.
- References: nixos/modules/private.nix, nixos/hosts/private/README.md,
  docs/PROVISIONING.md, .gitignore

- Date: 2026-01-20
- Change: Documented private overrides in confidentiality guide.
- Details: Added guidance to use `nixos/hosts/private/overrides.nix`.
- References: docs/CONFIDENTIALITY.md

- Date: 2026-01-20
- Change: Added private per-host overrides support.
- Details: Flake now loads private host modules when present.
- References: flake.nix, nixos/hosts/private/README.md

- Date: 2026-01-20
- Change: Added private hostname overrides.
- Details: Added per-node private hostnames for rpi-box nodes.
- References: nixos/hosts/private/pi-node-01.nix

- Date: 2026-01-20
- Change: Fixed SSH key assertion and removed deprecated RPi boot loader config.
- Details: Require admin SSH key file and rely on SD image modules for boot.
- References: nixos/modules/users.nix, nixos/profiles/rpi4.nix

- Date: 2026-01-20
- Change: Added tmpfiles rule for SSH authorized_keys directory.
- Details: Ensure `/etc/ssh/authorized_keys` exists on boot.
- References: nixos/modules/ssh.nix

- Date: 2026-01-20
- Change: Allowed empty SSH keys at build time.
- Details: Enabled `users.allowNoPasswordLogin` and removed key file reference.
- References: nixos/modules/ssh.nix, docs/PROVISIONING.md

- Date: 2026-01-20
- Change: Documented extra-platforms for cross-arch builds.
- Details: Added Nix config guidance for aarch64/armv7l.
- References: docs/PROVISIONING.md

- Date: 2026-01-20
- Change: Disabled enableAllHardware for Pi profiles.
- Details: Prevents missing-module failures during kernel module shrink.
- References: nixos/profiles/rpi4.nix, nixos/profiles/rpi3.nix

- Date: 2026-01-20
- Change: Documented QEMU/binfmt setup for ARM builds.
- Details: Added Ubuntu instructions for cross-architecture provisioning.
- References: docs/PROVISIONING.md

- Date: 2026-01-20
- Change: Added provisioning troubleshooting notes.
- Details: Documented common cross-architecture build errors and fixes.
- References: docs/PROVISIONING.md
