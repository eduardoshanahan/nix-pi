# Codex Sandbox vs Nix Daemon (SOPS) Runbook

## Problem

When commands are executed inside the default Codex sandbox, operations that need
the local Nix daemon may fail with errors like:

```text
error: cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Operation not permitted
```

This appears often during SOPS updates done through `nix develop -c ...`, for example:

- `nix develop -c sops set ...`
- `nix develop -c sops -d ...`

## Why it happens

- Codex sandbox mode restricts access to some host resources.
- The Nix daemon socket is outside what sandboxed commands can use.
- Result: first attempt fails even though command syntax is correct.

## Correct approach (first attempt)

If a command uses `nix`, `nix develop`, or anything that needs the daemon:

1. Run it with elevated permissions immediately (`require_escalated` in Codex tool calls).
2. Include a short justification (for example: "update encrypted SOPS keys").
3. If possible, use a stable approved prefix rule so future runs do not prompt again.

## Practical examples

Use elevated execution for:

- `nix develop -c sops set --in-place ...`
- `nix develop -c sops -d secrets/secrets.yaml`
- `nix eval`, `nix build`, `nixos-rebuild` (when they touch daemon/socket paths)

## Recommendation

For this repo, treat all `nix*` + `sops` workflows as "escalate-first" to avoid
false failures and repeated retries.
