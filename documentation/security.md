# Security / what not to commit

This repo is intended to be safe to publish publicly. Keep environment-specific and sensitive data out of git.

## Never commit

- Private SSH keys (`~/.ssh/id_*`)
- Passwords, API tokens, registry credentials, VPN keys
- Wi‑Fi PSKs and other secrets

## Prefer to keep private (even if not strictly secret)

- Your LAN IP plan and host ↔ IP mapping
- Personal SSH public keys (identify you and your machines)
- Hardware identifiers if you consider them sensitive (disk UUIDs, MACs)

## This repo’s local-only files

- SSH authorized keys: `local/authorized-keys.nix` (copy from `local/authorized-keys.nix.example`)
- LAN IP mapping: `documentation/ip-addresses.local.md` (copy from `documentation/ip-addresses.md`)

These are ignored by `.gitignore`.

