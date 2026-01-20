# Work Log

Format

- Date: YYYY-MM-DD
- Work: short description
- Details: brief notes
- References: optional links/paths

---

- Date: 2026-01-20
- Work: Set up project records structure.
- Details: Added records directory and baseline templates for decisions, work log,
  questions, and session prompt.
- References: records/README.md

- Date: 2026-01-20
- Work: Added risk, milestone, changelog, and ADR tracking.
- Details: Created new log files and an architecture-decisions directory with a
  per-decision template.
- References: records/RISKS.md, records/MILESTONES.md, records/CHANGELOG.md,
  records/architecture-decisions/README.md

- Date: 2026-01-20
- Work: Recorded ADR review cadence.
- Details: Set ADR reviews for session start and major changes.
- References: records/DECISIONS.md, records/QUESTIONS.md

- Date: 2026-01-20
- Work: Added flake-based dev shell and setup guide.
- Details: Created `flake.nix`, onboarding instructions, and ADR for flakes
  decision.
- References: flake.nix, docs/SETUP.md,
  records/architecture-decisions/0001-use-nix-flakes.md

- Date: 2026-01-20
- Work: Added confidentiality guidance and Git hygiene defaults.
- Details: Created confidentiality guide, added `.gitignore`, and logged initial
  milestones and risks.
- References: docs/CONFIDENTIALITY.md, .gitignore, records/MILESTONES.md,
  records/RISKS.md

- Date: 2026-01-20
- Work: Added prek and secrets scanning.
- Details: Added `prek` and `gitleaks` to the dev shell and created
  `.pre-commit-config.yaml`.
- References: flake.nix, .pre-commit-config.yaml, docs/SETUP.md,
  records/architecture-decisions/0002-use-prek-and-gitleaks.md

- Date: 2026-01-20
- Work: Added markdown linting to pre-commit config.
- Details: Added markdownlint-cli2 hook; attempted to run checks but `nix` was
  unavailable in this environment.
- References: .pre-commit-config.yaml

- Date: 2026-01-20
- Work: Attempted to run pre-commit checks.
- Details: `nix develop -c prek run --all-files` failed because the repo is not
  initialized as Git; `flake.lock` was created by `nix develop`.
- References: flake.lock

- Date: 2026-01-20
- Work: Initialized Git and fixed pre-commit checks.
- Details: Ran `git init`, staged files for flakes, corrected gitleaks args, and
  resolved markdownlint warnings across docs and records.
- References: .pre-commit-config.yaml, docs/SETUP.md, records/CHANGELOG.md

- Date: 2026-01-20
- Work: Documented why `prek install` is manual.
- Details: Added explanation in setup docs about `nix develop` vs git hooks.
- References: docs/SETUP.md

- Date: 2026-01-20
- Work: Added first-time setup checklist.
- Details: Documented a short onboarding checklist for new contributors.
- References: docs/SETUP.md

- Date: 2026-01-20
- Work: Captured Pi fleet requirements.
- Details: Recorded admin/per-node users, Ethernet-only, and hostname assignment.
- References: records/DECISIONS.md, records/QUESTIONS.md

- Date: 2026-01-20
- Work: Recorded Docker access, SSH key handling, and sync constraints.
- Details: Added decisions for docker group, manual public key injection, and
  file sync compatibility.
- References: records/DECISIONS.md, records/QUESTIONS.md

- Date: 2026-01-20
- Work: Added NixOS provisioning structure for Pi fleet.
- Details: Created flake outputs, NixOS modules, host profiles, and provisioning
  docs for SD image builds and SSH key injection.
- References: flake.nix, nixos/modules/options.nix, docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Updated linting after provisioning changes.
- Details: Fixed markdownlint issues and re-ran `prek` checks successfully.
- References: records/DECISIONS.md, docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Linked provisioning docs from setup guide.
- Details: Added pointer to `docs/PROVISIONING.md` in setup notes.
- References: docs/SETUP.md

- Date: 2026-01-20
- Work: Anonymized repo defaults and added private overrides.
- Details: Replaced personal identifiers with placeholders and added a
  gitignored private overrides path.
- References: nixos/modules/private.nix, nixos/hosts/private/README.md,
  docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Documented private overrides in confidentiality guide.
- Details: Added guidance to use `nixos/hosts/private/overrides.nix`.
- References: docs/CONFIDENTIALITY.md

- Date: 2026-01-20
- Work: Added private per-host overrides support.
- Details: Updated flake to load private host modules and clarified override docs.
- References: flake.nix, nixos/hosts/private/README.md, docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Added private hostname overrides.
- Details: Created private per-node host overrides for rpi-box hostnames.
- References: nixos/hosts/private/pi-node-01.nix

- Date: 2026-01-20
- Work: Fixed ARM build assertions for SSH and bootloader.
- Details: Removed deprecated raspberryPi boot loader config and ensured admin
  SSH key file is required in user config.
- References: nixos/modules/users.nix, nixos/profiles/rpi4.nix, docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Fixed SSH authorized_keys directory handling.
- Details: Added tmpfiles rule to create `/etc/ssh/authorized_keys` during boot.
- References: nixos/modules/ssh.nix

- Date: 2026-01-20
- Work: Allowed empty SSH key config during image build.
- Details: Enabled `users.allowNoPasswordLogin` and removed keyFiles to avoid
  impure path access; manual key injection remains required.
- References: nixos/modules/ssh.nix, docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Documented extra-platforms for cross-arch builds.
- Details: Added instructions to enable aarch64/armv7l in Nix config.
- References: docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Disabled `hardware.enableAllHardware` for Pi images.
- Details: Avoids module shrink failures for missing kernel modules on RPi.
- References: nixos/profiles/rpi4.nix, nixos/profiles/rpi3.nix

- Date: 2026-01-20
- Work: Added QEMU/binfmt instructions for ARM image builds.
- Details: Documented Ubuntu steps to enable binfmt for cross-arch builds.
- References: docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Added provisioning troubleshooting section.
- Details: Documented common cross-architecture build failures and fixes.
- References: docs/PROVISIONING.md
