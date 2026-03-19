# Commit And Hooks Policy

This workspace contains three Nix-based repos:

- `nix-pi`
- `nix-services`
- `synology-services`

## Rule

- Do not treat missing hook tools as a reason to bypass hooks.
- Do not default to `git commit --no-verify`.
- Do not default to bypassing checks just because a hook command is not found in the current shell.

## Expected workflow

For any of these repos, enter the repo-local dev shell before commit or push:

```bash
cd <repo>
nix develop
```

Inside that shell, the repo-provided hook toolchain should be available, including the tools used by `prek` hooks such as:

- `prek`
- `gitleaks`
- `markdownlint-cli2`
- `deadnix`
- other repo-specific CLI dependencies included by that repo's `flake.nix`

## Operational guidance

- If a commit fails because a hook tool is missing, the first fix is to enter `nix develop` in that repo and retry.
- If needed, run the hooks explicitly from the dev shell:

```bash
prek run --all-files
```

- Only consider bypassing hooks after confirming there is an exceptional reason and the user explicitly wants that tradeoff.

## Why this exists

This issue has come up repeatedly in this workspace.

The normal path is:

1. `cd nix-pi` or `cd nix-services` or `cd synology-services`
2. `nix develop`
3. run commits and pushes from that shell

That is the intended environment for these repos.
