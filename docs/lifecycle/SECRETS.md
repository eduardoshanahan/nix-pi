# Secrets (sops-nix + age)

This repo provisions secrets at activation/boot time using `sops-nix`.
Decrypted material is written only to `/run/secrets` (tmpfs) and is lost on reboot.

## Assumptions (per host)

- The age private key already exists on the host at `/var/lib/sops/age.key`.
- The corresponding age public key is safe to commit (it is only a recipient identifier).

## One-time host bootstrap (required)

Before a host can decrypt any SOPS-managed secret, bootstrap its age private key.

Recommended helper:

```bash
scripts/bootstrap-sops-age-key <source-host> <target-host> [target-host...]
```

Example:

```bash
scripts/bootstrap-sops-age-key pi-node-a pi-node-b pi-node-c
```

This copies `/var/lib/sops/age.key` from the source host to each target host
with mode `0600`.

## Configure SOPS recipients

Add your age recipients to `.sops.yaml` (public keys only), for example:

```yaml
creation_rules:
  - path_regex: secrets/.*\\.ya?ml$
    age:
      - "age1..."
```

## Create encrypted secret files

Create one file per host (recommended) or a shared file:

```bash
sops --encrypt --in-place secrets/pi-node-a.yaml
```

Then add keys/values inside the file using `sops` (it will keep values encrypted).

## Declare secrets in NixOS

In a host module, declare secrets and ensure services read from `/run/secrets`:

```nix
{ ... }:
{
  sops.secrets."myservice.env" = {
    sopsFile = ../../secrets/pi-node-a.yaml;
    format = "dotenv";
    path = "/run/secrets/myservice.env";
    owner = "root";
    group = "root";
    mode = "0400";
  };
}
```

Notes:

- Only encrypted SOPS files are stored in the Nix store; decrypted outputs stay in `/run/secrets`.
- In the live paired setup, `../nix-pi-private/secrets/secrets.yaml` is the canonical shared default and `nix-pi-private/modules/shared.nix` sets it as `lab.sops.defaultSopsFile`.
- Do not add new long-lived shared secrets to `nix-pi/secrets/secrets.yaml`; keep them in the private companion repo instead.

## Remote builder signing keys

Nix builder signing keys are separate from SOPS and are not stored in Git or in
the Nix store. They are operational host identities used so one machine can
trust store paths built on another machine.

If a builder host must recover an existing signing identity after reinstall,
bootstrap the keypair explicitly:

```bash
scripts/bootstrap-nix-signing-key <key-name> <source-host> <target-host> [target-host...]
scripts/bootstrap-nix-signing-key --from-files <private-key-file> <public-key-file> <key-name> <target-host> [target-host...]
```

Keep any backup copy of the private signing key outside Git, and treat it like
other privileged host material.

See `docs/lifecycle/REMOTE_BUILDS.md` for the trust model and rotation procedure.
