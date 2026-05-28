# Constraints — nix-pi (public)

This file contains only public-safe constraints. Authoritative constraints (including
private network topology, real host identifiers, and deployment specifics) live in
`../nix-pi-private/.brain/constraints.md`.

---

## Public/Private Boundary

- This `.brain/` directory is pushed to Gitea — never add sensitive content here
- Raw investigations always go to the private brain (`../nix-pi-private/.brain/`)
- Only sanitized content published via `brainctl publish` belongs here
- Never include real hostnames, internal IPs, or credentials in this repo

## NixOS

- Always pin NixOS channel versions
- Test changes with `nixos-rebuild test` before `switch`
- Pass `--override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"` for all builds

## Git / Pre-commit

- Never use `--no-verify` — enter `nix develop` and rerun instead
- Commit via `nix develop --command git commit` so pre-commit hooks have required tools
- After every `nix flake update` on a Gitea input, sanitize `flake.lock`:
  replace the real internal hostname with `gitea.internal.example` before committing

## Documentation Structure

- `docs/` is for human-facing documentation; `.brain/` is for agent-facing rules
- ADRs belong in `docs/decisions/` — they have lasting human value
- `records/` is superseded by `.brain/investigations/` — do not create new `records/` files
- Pointer-only doc files should be deleted; agents read canonical sources directly
