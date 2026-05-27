# `docs/`

Human-facing documentation for the `nix-pi` homelab layer.

- `setup/` — first-time onboarding and host provisioning
  - `SETUP.md` — dev shell and prerequisites
  - `PROVISIONING.md` — headless SD card workflow
  - `SECRETS.md` — sops-nix/age secrets management

- `operations/` — day-to-day operator reference
  - `REMOTE_BUILDS.md` — cross-host nixos-rebuild flows
  - `HOST_RUNTIME_DIVERGENCES.md` — intentional per-host divergences from shared modules
  - `UPTIME_KUMA_MONITOR_POLICY.md` — declarative Kuma monitor inventory

- `recovery/` — break-glass runbooks
  - `backup_strategy.md` — what is backed up and how
  - `reflash_rejoin_node_runbook.md` — reflash and rejoin a node from scratch

- `decisions/` — why things are the way they are
  - `CONFIDENTIALITY.md` — what to keep out of Git and how
  - `ADR-0001-nix-flakes.md` — use Nix flakes for dev shell onboarding
  - `ADR-0002-prek-gitleaks.md` — use prek with gitleaks for pre-commit scanning

See `README.md` at the repo root for the ownership boundary and overall structure.
