# Architecture Decision

- ID: 0002
- Title: Use prek with gitleaks for secrets scanning
- Date: 2026-01-20
- Status: accepted
- Context: Need a pre-commit workflow with a secrets scan as the first check.
- Decision: Use `prek` as the pre-commit runner and `gitleaks` as the initial
  hook.
- Rationale: `prek` is fast and drop-in compatible; `gitleaks` is a standard
  secrets scanner.
- Consequences: Contributors need `prek` available (provided via Nix dev shell).
- References: .pre-commit-config.yaml, flake.nix, docs/SETUP.md
