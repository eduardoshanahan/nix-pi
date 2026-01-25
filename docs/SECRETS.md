# Secrets (sops-nix + age)

This repo provisions secrets at activation/boot time using `sops-nix`.
Decrypted material is written only to `/run/secrets` (tmpfs) and is lost on reboot.

## Assumptions (per host)

- The age private key already exists on the host at `/var/lib/sops/age.key`.
- The corresponding age public key is safe to commit (it is only a recipient identifier).

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
sops --encrypt --in-place secrets/rpi-box-01.yaml
```

Then add keys/values inside the file using `sops` (it will keep values encrypted).

## Declare secrets in NixOS

In a host module, declare secrets and ensure services read from `/run/secrets`:

```nix
{ ... }:
{
  sops.secrets."myservice.env" = {
    sopsFile = ../../secrets/rpi-box-01.yaml;
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
- If you create `secrets/secrets.yaml`, `nixos/modules/secrets.nix` will auto-use it as `sops.defaultSopsFile`.
