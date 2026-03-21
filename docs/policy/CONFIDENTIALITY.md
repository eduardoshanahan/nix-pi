# Confidentiality & Publishing

This project may be published on GitHub. Keep confidential data out of Git and
anonymize artifacts before sharing.

## Rules of thumb

- Do not commit secrets, credentials, tokens, or private identifiers.
- Encrypted secrets (for example SOPS-encrypted files under `secrets/`) are allowed to be committed.
- Keep private datasets and raw logs out of the repo; store them outside the
  workspace.
- Anonymize any artifacts that could reveal sensitive information.

## Suggested workflow

1) Keep confidential inputs in a sibling private companion repo when they are
   part of the evaluated Nix configuration.
2) Generate anonymized or redacted outputs into the public repo.
3) Use runtime secret files or environment variables for decrypted secret
   material.

## Git hygiene

- Use `.gitignore` to exclude local-only files and private folders.
- If a secret is committed, rotate it immediately and rewrite history before
  publishing.

## Optional local config

If needed, add a `config/local.env` or similar file and keep it out of Git.
For evaluated private NixOS values, use the sibling `nix-pi-private` repo.
