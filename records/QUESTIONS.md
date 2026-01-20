# Open Questions

Format

- Date: YYYY-MM-DD
- Question: short prompt
- Context: brief background
- Status: open/answered
- Answer: fill in when resolved

---

- Date: 2026-01-20
- Question: Are you OK with the `records/` structure and file set, or do you
  prefer a different location/format?
- Context: Initial setup for long-term project tracking.
- Status: answered
- Answer: Approved as-is.

- Date: 2026-01-20
- Question: What cadence should we use to review architecture decisions for
  conflicts (e.g., weekly, per milestone, per major change)?
- Context: You requested regular reviews to ensure ADRs remain compatible.
- Status: answered
- Answer: Review per major change and at the start of each working session.

- Date: 2026-01-20
- Question: Should we standardize on flakes (recommended) or also support legacy
  non-flake Nix commands?
- Context: You want onboarding to work on Ubuntu or NixOS with `nix develop` /
  `nix shell`.
- Status: answered
- Answer: Standardize on flakes (`flake.nix`).

- Date: 2026-01-20
- Question: Should we adopt `prek` as the pre-commit runner and include it in
  the dev shell?
- Context: You asked to review [j178/prek](https://github.com/j178/prek) for use
  with a pre-commit scan.
- Status: answered
- Answer: Yes. Adopt `prek` and add a secrets scan as the first check.

- Date: 2026-01-20
- Question: Which user model, SSH strategy, and networking assumptions apply for
  the Pi fleet?
- Context: Planning automated provisioning for NixOS Pis and host access.
- Status: answered
- Answer: Admin user on every machine plus per-box users as needed; no Wi-Fi;
  hostnames preferred; SSH keys in host agent, prefer forwarding; asked about
  Docker implications.

- Date: 2026-01-20
- Question: Should the admin user be added to the `docker` group, and can the
  SSH public key be added manually to SD cards?
- Context: Docker access and first-boot SSH requirements.
- Status: answered
- Answer: Add admin to `docker` group; manual key injection is acceptable
  (public key at `~/.ssh/id_ed25519.pub`).

- Date: 2026-01-20
- Question: Are there constraints from file sync we must honor?
- Context: Repo is synchronized across machines via a file sync tool.
- Status: answered
- Answer: Yes; avoid permissions or files that break across machines.
