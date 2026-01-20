# Setup

This project uses a Nix flake dev shell for consistent onboarding.

## Prerequisites

- Ubuntu or NixOS host
- Nix installed with flakes enabled

## Install Nix (Ubuntu)

If you do not already have Nix installed, follow the official installer:

- [Nix download](https://nixos.org/download)

After installation, enable flakes and the new CLI:

```bash
mkdir -p ~/.config/nix
cat <<'CONF' > ~/.config/nix/nix.conf
experimental-features = nix-command flakes
CONF
```

## Install Nix (NixOS)

In `configuration.nix`:

```nix
{ ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

## Enter the dev shell

From the repo root:

```bash
nix develop
```

This should print: `Entering nix-pi-2 dev shell`.

## Pre-commit checks (prek)

This project uses `prek` with a `.pre-commit-config.yaml`.

Install git hooks:

```bash
prek install
```

Why this is manual: `nix develop` only sets up tools, it does not modify the
repo. `prek install` writes the hook into `.git/hooks`, which is local state.

Run checks on all files:

```bash
prek run --all-files
```

The first check is a secrets scan via `gitleaks`.

## First-time setup checklist

- Install Nix with flakes enabled.
- Initialize Git in the repo (`git init`) if it is not already a Git repo.
- Enter the dev shell (`nix develop`).
- Install hooks (`prek install`).
- Run checks (`prek run --all-files`).

## Notes

- The dev shell definition lives in `flake.nix`.
- If you need additional tools, update `devShells.default.packages` in `flake.nix`.
- If `nix develop` reports `flake.nix` is not tracked, run `git init` and
  `git add flake.nix flake.lock` before retrying.
- See `docs/PROVISIONING.md` for Raspberry Pi SD image workflow.
