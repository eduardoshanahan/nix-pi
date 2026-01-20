# Architecture Decision

- ID: 0001
- Title: Use Nix flakes for dev shell onboarding
- Date: 2026-01-20
- Status: accepted
- Context: Need consistent onboarding on Ubuntu or NixOS and reusable dev
  environments.
- Decision: Use `flake.nix` with `nix develop` as the primary entry point.
- Rationale: Flakes provide reproducible inputs and a standard dev shell workflow.
- Consequences: Requires enabling flakes for contributors; legacy `shell.nix` is
  not provided.
- References: flake.nix, docs/SETUP.md
