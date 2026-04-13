# Encrypted secrets (SOPS)

This directory is for SOPS-encrypted secret files that are safe to commit to Git.

- Do not commit plaintext secrets.
- Decrypted secrets are written at activation/boot to `/run/secrets` (tmpfs).
- The per-host age private key must live on the host (not in Git, not in the Nix store).

Recommended layout:

- `secrets/<hostname>.yaml`: host-specific secrets (optional)

The live shared default secrets file now lives in `../nix-pi-private/secrets/secrets.yaml`.
Keep new shared private values there instead of recreating `secrets/secrets.yaml` here.

SOPS configuration lives at `.sops.yaml`. See `docs/lifecycle/SECRETS.md` for the workflow and examples.
