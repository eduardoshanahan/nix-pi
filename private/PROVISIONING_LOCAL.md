# Local Provisioning Runbook (Private)

This file is gitignored (`private/`) and is intended to contain exact commands
for the current lab setup (usernames, key paths, IPs, etc).

## Build images (include private companion config)

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nix build --override-input private "path:$NIX_PI_PRIVATE_FLAKE" path:$PWD#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
nix build --override-input private "path:$NIX_PI_PRIVATE_FLAKE" path:$PWD#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

Optional: keep local copies in the repo (for sync/backups):

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4 --decompress
scripts/export-sd-image result-rpi3 sd-image rpi3 --decompress
```

## Flash SD card

Pick the right image and device, then flash (examples):

```bash
# Uncompressed image:
sudo dd if=sd-image/rpi4.img of=/dev/sdX bs=4M conv=fsync status=progress

# Or, flash compressed image without storing the full .img:
zstd -dc sd-image/rpi4.img.zst | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

## Inject SSH key (headless first boot)

### Recommended: no SD card modification

Set `lab.adminAuthorizedKeys` in `../nix-pi-private/modules/shared.nix`,
rebuild with the private flake override, flash, and boot. This removes the SD
mounting/key injection step.

### Fallback: inject key onto mounted SD card

After flashing, reinsert the SD card so it mounts. Confirm partitions:

```bash
lsblk -f
```

Inject the public key for the configured admin user:

```bash
scripts/inject-ssh-key /media/eduardo/NIXOS_SD ~/.ssh/eduardo-hhlab.pub --user eduardo
```

If you need a safety fallback, inject the same key for `admin` too:

```bash
scripts/inject-ssh-key /media/eduardo/NIXOS_SD ~/.ssh/eduardo-hhlab.pub --user eduardo --user admin
```

Unmount before removing the card:

```bash
sync
udisksctl unmount -b /dev/sdX2
udisksctl unmount -b /dev/sdX1
```

## First SSH

If the host was reflashed, clear the old host key:

```bash
ssh-keygen -R 192.0.2.10
```

Then connect:

```bash
ssh eduardo@192.0.2.10
```

## Remote builder note (`pi-node-c`)

`pi-node-c` is rebuilt using `pi-node-b` as the builder:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nixos-rebuild switch \
  --flake path:$PWD#pi-node-c \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --target-host eduardo@pi-node-c \
  --build-host eduardo@pi-node-b \
  --sudo
```

Steady-state requirements:

- `pi-node-b` must keep its Nix signing key at `/etc/nix/pi-node-b-priv.pem`.
- `pi-node-c` must trust the matching public key
  `pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=`.
- Keep a secure backup of `/etc/nix/pi-node-b-priv.pem` and `/etc/nix/pi-node-b-pub.pem`
  outside Git so the same builder identity can be restored intentionally.

If `pi-node-c` is rebuilt from scratch or the builder signing key changes,
restore that trust relationship before relying on the remote builder again.

To restore the builder identity onto a rebuilt `pi-node-b` from local backup:

```bash
scripts/bootstrap-nix-signing-key \
  --from-files \
  ./pi-node-b-priv.pem \
  ./pi-node-b-pub.pem \
  pi-node-b \
  pi-node-b
```
