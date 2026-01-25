# Encrypted secrets (SOPS)

This directory is for SOPS-encrypted secret files that are safe to commit to Git.

- Do not commit plaintext secrets.
- Decrypted secrets are written at activation/boot to `/run/secrets` (tmpfs).
- The per-host age private key must live on the host (not in Git, not in the Nix store).

Recommended layout:

- `secrets/secrets.yaml`: shared secrets (optional)
- `secrets/<hostname>.yaml`: host-specific secrets (optional)

SOPS configuration lives at `.sops.yaml`. See `docs/SECRETS.md` for the workflow and examples.
