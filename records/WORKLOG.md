# Work Log

Format

- Date: YYYY-MM-DD
- Work: short description
- Details: brief notes
- References: optional links/paths

---

- Date: 2026-01-22
- Work: Switched Pi 3 builds to aarch64 by default.
- Details: Pi 3 armv7l SD image builds on x86 were extremely slow (multi-hour)
  due to limited substitutes and heavy compilation under QEMU/binfmt. Updated
  flake outputs and provisioning docs to build Pi 3 as `aarch64-linux`, keeping
  an optional `rpi3-armv7l` output for 32-bit fallback.
- References: flake.nix, nixos/profiles/rpi3.nix, nixos/profiles/rpi3-armv7l.nix,
  docs/PROVISIONING.md

- Date: 2026-01-22
- Work: Removed public per-host configurations.
- Details: Removed public `rpi-box-*` flake outputs and host modules to keep the
  repo anonymized and reduce churn. Hostnames are set after first boot (or via
  private overrides if desired). Kept `nixos/hosts/example-host.nix` as a pattern.
- References: flake.nix, nixos/hosts/example-host.nix, docs/PROVISIONING.md

- Date: 2026-01-21
- Work: Attempted Pi 3 SD image build.
- Details: Started a Pi 3 `nix build` with `NIXPKGS_ALLOW_BROKEN=1`;
  build requires Nix daemon access and continued beyond tool timeout, leaving
  `result-rpi3` absent.
- References: flake.nix, docs/PROVISIONING.md

- Date: 2026-01-21
- Work: Handed off Pi 3 image build to local terminal.
- Details: User will run the build command directly to avoid tool timeouts; waiting
  on outcome and `result-rpi3` creation.
- References: docs/PROVISIONING.md, records/SESSION_PROMPT.md

- Date: 2026-01-21
- Work: Diagnosed Pi 3 build failure due to missing Nix `system-features`.
- Details: `nix build` failed on x86_64 because `system-features` lacked
  `gccarch-armv7-a`; fix is to add it (preserving existing features) in
  `/etc/nix/nix.conf` for multi-user Nix and restart `nix-daemon`.
- References: docs/PROVISIONING.md, records/SESSION_PROMPT.md

- Date: 2026-01-21
- Work: Updated Nix daemon config for armv7l builds.
- Details: Added `gccarch-armv7-a` to `system-features` in `/etc/nix/nix.conf`
  and verified `nix show-config` reports the feature.
- References: docs/PROVISIONING.md

- Date: 2026-01-21
- Work: Added generic Pi 3/Pi 4 image outputs.
- Details: Flake now exposes `nixosConfigurations.rpi4` and `.rpi3` for building
  one image per architecture without embedding host-specific `networking.hostName`.
- References: flake.nix, docs/PROVISIONING.md, records/DECISIONS.md

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
- Details: Added gitignored private host overrides support for local hostnames
  and environment-specific values.
- References: nixos/hosts/private/README.md

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

- Date: 2026-01-20
- Work: Recorded session-start file scan policy.
- Details: Added decision and session prompt note to read all text files
  (tracked and untracked, including private/secrets) while excluding `.git`
  and binaries.
- References: records/DECISIONS.md, records/SESSION_PROMPT.md

- Date: 2026-01-20
- Work: Standardized host naming and configs.
- Details: Replaced the earlier `pi-node-*` naming scheme with the current host
  naming convention, updated provisioning docs, and aligned private overrides.
- References: flake.nix, docs/PROVISIONING.md

- Date: 2026-01-20
- Work: Agreed on two-image build plan.
- Details: Build one Pi 4 (aarch64) image and one Pi 3 (armv7l) image; set
  hostnames after imaging.
- References: records/DECISIONS.md

- Date: 2026-01-20
- Work: Fixed Pi 3 SD image module import.
- Details: Updated rpi3 profile to use `sd-image-armv7l-multiplatform.nix`
  because `sd-image-armv7l.nix` is no longer present in nixpkgs.
- References: nixos/profiles/rpi3.nix

- Date: 2026-01-20
- Work: Built Pi 4 SD image and started Pi 3 build.
- Details: Built aarch64 image to `result-rpi4`. Pi 3 build requires
  `NIXPKGS_ALLOW_BROKEN=1` and daemon `system-features` to include
  `gccarch-armv7-a`; build was started but not completed within tool timeout.
- References: flake.nix, nixos/profiles/rpi3.nix
