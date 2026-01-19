# Runbook: Deploy (nixos-rebuild switch)

Goal: apply the configuration for a host from this repo to the target machine.

## Run

```bash
./scripts/deploy <host> root@<ip-or-dns>
```

## Prereq: SSH keys

Ensure you have `local/authorized-keys.nix` configured (see `local/authorized-keys.nix.example`). Deploys and SD-image builds assert that at least one root key is configured.

Examples:

```bash
./scripts/deploy rpi-box-01 root@<ip-or-dns>
./scripts/deploy rpi-box-02 root@<ip-or-dns>
./scripts/deploy rpi-box-03 root@<ip-or-dns>
```

### Build location

By default, `scripts/deploy` builds on the target host (`--build-host` = target).

Override:

- Build locally (if your workstation can build aarch64): `BUILD_HOST=local ./scripts/deploy ...`
- Build on a separate builder: `BUILD_HOST=root@<builder> ./scripts/deploy ...`

## Verify

On the target:

```bash
nixos-version
sudo systemctl is-system-running
```

On the workstation:

- Re-run the deploy and confirm it reports “up to date” (no changes).
