# Decisions

Format

- Date: YYYY-MM-DD
- Decision: short statement
- Context: brief background
- Rationale: why this was chosen
- Status: active/superseded
- References: optional links/paths

---

- Date: 2026-01-20
- Decision: Initialize project records under `records/` at repo root.
- Context: User requested long-term decision/work/session tracking for this
  project.
- Rationale: Simple, discoverable location with small, focused files.
- Status: active
- References: records/README.md

- Date: 2026-01-20
- Decision: Add risk, milestone, and changelog tracking plus an architecture
  decisions directory.
- Context: User requested additional record types and
  one-file-per-architecture-decision.
- Rationale: Separate files keep logs focused while ADRs stay discrete and reviewable.
- Status: active
- References: records/RISKS.md, records/MILESTONES.md, records/CHANGELOG.md,
  records/architecture-decisions/README.md

- Date: 2026-01-20
- Decision: Review ADRs at the start of each working session and per major
  change.
- Context: Need regular checks to prevent conflicting architecture decisions.
- Rationale: Ties reviews to meaningful change points and session starts.
- Status: active
- References: records/architecture-decisions/README.md, records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Standardize on Nix flakes for dev shell onboarding.
- Context: Need consistent setup on Ubuntu or NixOS and `nix develop` support.
- Rationale: Flakes provide reproducible inputs and a clear onboarding path.
- Status: active
- References: flake.nix, docs/SETUP.md,
  records/architecture-decisions/0001-use-nix-flakes.md

- Date: 2026-01-20
- Decision: Keep confidential data out of Git and anonymize artifacts before
  publishing.
- Context: Project may be published to GitHub; sensitive inputs must remain
  private.
- Rationale: Prevents leakage of credentials and private data while enabling
  open collaboration.
- Status: active
- References: docs/CONFIDENTIALITY.md, .gitignore

- Date: 2026-01-20
- Decision: Use `prek` with a secrets scan (gitleaks) as the first pre-commit
  check.
- Context: Need automated protection against committing sensitive data.
- Rationale: `prek` is a fast drop-in alternative and gitleaks is a standard
  secrets scanner.
- Status: active
- References: .pre-commit-config.yaml, flake.nix, docs/SETUP.md,
  records/architecture-decisions/0002-use-prek-and-gitleaks.md

- Date: 2026-01-20
- Decision: Use an admin account on all Pis plus optional per-node users.
- Context: Need centralized admin access with room for box-specific access.
- Rationale: Balances operational access with per-node delegation.
- Status: active
- References: records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Use Ethernet only (no Wi-Fi) for initial provisioning.
- Context: Current lab setup uses wired networking; no Wi-Fi needed.
- Rationale: Simplifies NixOS config and reduces moving parts.
- Status: active
- References: records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Assign hostnames at build time (e.g., `<hostname>`).
- Context: Need predictable identification in DHCP and SSH access.
- Rationale: Easier to map reserved IPs and roles to nodes.
- Status: superseded
- References: records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Add the admin user to the `docker` group for convenience.
- Context: Need Docker access without `sudo` on the Pis.
- Rationale: Speeds up operational work; accepted root-equivalent implications.
- Status: active
- References: records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Manually add the admin public key to SD cards at imaging time.
- Context: SSH access is required on first boot; key lives at
  `~/.ssh/id_ed25519.pub`.
- Rationale: Manual injection is acceptable and avoids copying private keys
  into the repo.
- Status: superseded
- References: records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Ensure repo layout and configs stay compatible with file sync.
- Context: Project is synchronized across machines via a file sync tool.
- Rationale: Avoid platform-specific permissions or files that break on another machine.
- Status: active
- References: records/QUESTIONS.md

- Date: 2026-01-20
- Decision: Use NixOS flake configs with nixos-hardware modules for RPi3/4 SD images.
- Context: Need reproducible provisioning for mixed RPi models.
- Rationale: Leverages maintained hardware profiles and standard SD image modules.
- Status: active
- References: flake.nix, nixos/profiles/rpi3.nix, nixos/profiles/rpi4.nix

- Date: 2026-01-20
- Decision: Use `/etc/ssh/authorized_keys/%u` for manual key injection.
- Context: SSH access is required at first boot without embedding keys in the repo.
- Rationale: Allows injecting public keys into the SD image without user home dirs.
- Status: active
- References: nixos/modules/ssh.nix, docs/PROVISIONING.md

- Date: 2026-01-22
- Decision: Embed admin public key(s) into SD images via `lab.adminAuthorizedKeys`
  (private overrides) and build with `path:.#...`.
- Context: Manual SD card edits are error-prone and slow down repeatability; the
  repo keeps sensitive values gitignored.
- Rationale: Fully automated first-boot SSH access without post-flash SD mounting,
  while keeping keys and usernames out of Git.
- Status: active
- References: nixos/modules/options.nix, nixos/modules/ssh.nix, docs/PROVISIONING.md,
  nixos/hosts/private/README.md

- Date: 2026-01-20
- Decision: Use public placeholders in the repo and keep sensitive overrides in
  a gitignored private overlay.
- Context: Repo may be published; need anonymized defaults and local-only data.
- Rationale: Keeps the public repo clean while supporting real deployments.
- Status: active
- References: nixos/modules/private.nix, nixos/hosts/private/README.md

- Date: 2026-01-20
- Decision: At the start of each session, read all text files in the workspace
  (tracked and untracked, including private/secrets), excluding `.git` and
  binaries, to rehydrate full context.
- Context: Avoid repeating onboarding/context questions across sessions.
- Rationale: Ensures full project state is captured before continuing work.
- Status: active
- References: records/SESSION_PROMPT.md

- Date: 2026-01-20
- Decision: Use device-specific hostnames as first-class names in flake configs.
- Context: Devices have stable hostnames and SD images can be built per host if
  desired.
- Rationale: Keeps host configs, DNS, and SSH mappings aligned with reality and
  avoids placeholder naming.
- Status: superseded
- References: flake.nix

- Date: 2026-01-20
- Decision: Build two SD images (one Pi 4 aarch64, one Pi 3 armv7l) and set
  hostnames later.
- Context: Fleet has two Pi 4 devices and one Pi 3 device; per-host images are
  optional if hostnames can be configured later.
- Rationale: Reduces build count while keeping architecture-specific images.
- Status: active
- References: docs/PROVISIONING.md

- Date: 2026-01-21
- Decision: Build two generic SD images (RPi4 and RPi3) without hostnames.
- Context: Fleet has two Pi 4 devices and one Pi 3 device; building per-host
  images adds unnecessary work and creates churn across machines.
- Rationale: One image per architecture is sufficient; hostnames can be set on
  first boot via `hostnamectl` and later automated if desired.
- Status: active
- References: flake.nix, docs/PROVISIONING.md

- Date: 2026-01-22
- Decision: Run the Pi 3 on 64-bit NixOS (`aarch64-linux`) by default; keep armv7l
  as an optional fallback.
- Context: Pi 3 armv7l SD image builds on x86 took many hours and compiled large
  toolchains under emulation due to limited binary cache coverage.
- Rationale: aarch64 builds have significantly better substitute coverage and are
  much faster on x86 hosts; Pi 3 hardware supports 64-bit.
- Status: active
- References: flake.nix, nixos/profiles/rpi3.nix, docs/PROVISIONING.md

- Date: 2026-02-22
- Decision: Keep `sops-nix` and standardize a one-time per-host age-key bootstrap script.
- Context: TLS rollout failed on a host that lacked `/var/lib/sops/age.key`, which
  blocked `sops-install-secrets` during activation.
- Rationale: This keeps the existing secrets architecture and makes the bootstrap
  precondition explicit, repeatable, and scriptable instead of ad-hoc.
- Status: active
- References: scripts/bootstrap-sops-age-key, docs/SECRETS.md, docs/PROVISIONING.md
