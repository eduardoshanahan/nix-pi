# Runbooks

Runbooks are the step-by-step procedures to operate this fleet.

Use these when you need to repeat a task reliably (or hand it off to another group).

## Conventions

- Keep procedures concrete and copy/pasteable.
- Prefer commands that use this repo as the single source of truth (`flake.nix` + `hosts/` + `modules/`).
- If a runbook changes a machine, include a short **Verify** section with checks to confirm success.
- If a runbook is performed as part of a significant change, add a diary entry in `documentation/diary/`.

## Index

- Bootstrap SD image: `documentation/runbooks/bootstrap-sd-image.md`
- Pull hardware config: `documentation/runbooks/pull-hardware.md`
- Deploy (switch): `documentation/runbooks/deploy.md`
- Rename a host: `documentation/runbooks/rename-host.md`

