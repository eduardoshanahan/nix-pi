# Confidentiality & Publishing

This project may be published on GitHub. Keep confidential data out of Git and
anonymize artifacts before sharing.

## Rules of thumb

- Do not commit secrets, credentials, tokens, or private identifiers.
- Keep private datasets and raw logs out of the repo; store them outside the
  workspace.
- Anonymize any artifacts that could reveal sensitive information.

## Suggested workflow

1) Keep confidential inputs in a local, untracked directory (outside the repo
   when possible).
2) Generate anonymized or redacted outputs into the repo.
3) Use environment variables or local-only config files for secrets.

## Git hygiene

- Use `.gitignore` to exclude local-only files and private folders.
- If a secret is committed, rotate it immediately and rewrite history before
  publishing.

## Optional local config

If needed, add a `config/local.env` or similar file and keep it out of Git.
Use `nixos/hosts/private/overrides.nix` for sensitive NixOS overrides.
