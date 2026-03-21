# Pi Provisioning (RPi 3 + RPi 4)

This document defines the repeatable, headless workflow for preparing NixOS SD
cards for Raspberry Pi devices. The goal is to minimize manual steps on the Pis
while keeping secrets out of Git.

## Assumptions

- Host machine: Ubuntu 25.10 x86_64 with Nix installed and flakes enabled.
- Network: DHCP only; IPs will be reserved after first boot.
- Access: SSH public key is injected onto the SD card before first boot.
- Admin user: configured via `lab.adminUser` (default is `admin`).

## Private companion repo (required)

Real private values now live in a sibling private flake:

- public repo: `nix-pi`
- private companion: `../nix-pi-private`

The public repo keeps only the tracked placeholder contract in
`private-config-template/`.

Before building or rebuilding, validate the active private config:

```bash
cd ~/Programming/gitea.internal.example/hhlab-insfrastructure/nix-pi
nix run "path:$PWD#validate-private-config" -- pi-node-a
```

## Build the SD image

### Important: private flake overrides

The public flake input named `private` points at the tracked placeholder by
default. For real builds, pass the sibling private flake explicitly:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nix build --override-input private "path:$NIX_PI_PRIVATE_FLAKE" path:$PWD#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
nix build --override-input private "path:$NIX_PI_PRIVATE_FLAKE" path:$PWD#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

### Recommended builds (one image per architecture)

RPi 4 (aarch64):

```bash
nix build --override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}" path:$PWD#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
```

RPi 3 (recommended: 64-bit aarch64 for better cache coverage and faster builds
on x86):

```bash
nix build --override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}" path:$PWD#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

Optional: RPi 3 in 32-bit mode (armv7l). Much slower on x86 hosts and may require
`--impure` and `NIXPKGS_ALLOW_BROKEN=1`:

```bash
NIXPKGS_ALLOW_BROKEN=1 nix build --impure --override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}" path:$PWD#nixosConfigurations.rpi3-armv7l.config.system.build.sdImage -o result-rpi3
```

If the build fails due to architecture emulation, enable binfmt support for
ARM on the host before retrying.

On Ubuntu (host), enable QEMU binfmt:

```bash
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support
sudo systemctl restart binfmt-support
```

Verify ARM support is registered:

```bash
ls /proc/sys/fs/binfmt_misc | rg -i 'arm|aarch64'
```

Enable cross-architecture builds in Nix:

For multi-user Nix (daemon), edit `/etc/nix/nix.conf`:

```conf
extra-platforms = aarch64-linux armv7l-linux
```

Then restart the daemon:

```bash
sudo systemctl restart nix-daemon
```

For single-user Nix, add the same line to `~/.config/nix/nix.conf`.

### Pi 3 (armv7l) builds: required `system-features`

Some armv7l builds require the `gccarch-armv7-a` system feature. If you see an
error like:

```text
Required system: 'armv7l-linux' with features {gccarch-armv7-a}
```

Check current features:

```bash
nix show-config | rg '^system-features'
```

For multi-user Nix (daemon), add `gccarch-armv7-a` to `system-features` in
`/etc/nix/nix.conf` (include your existing features), for example:

```conf
system-features = benchmark big-parallel kvm nixos-test uid-range gccarch-armv7-a
```

Then restart the daemon:

```bash
sudo systemctl restart nix-daemon
```

## Troubleshooting

Common issues when building ARM images on x86 hosts:

- Modules shrink failures (missing module): disable `hardware.enableAllHardware`
  in the RPi profiles to avoid pulling in non-existent kernel modules.
- `exec format error`: QEMU/binfmt is not enabled or not registered for ARM.
  Re-run the QEMU/binfmt setup and reboot if needed.
- `flake.nix is not tracked`: initialize Git in the repo and `git add flake.nix`
  (flakes require a Git working tree).
- Builds are very slow: cross-arch builds can be heavy; prefer using the Nix
  cache and avoid building from source where possible.

Output image path (example):

```text
./result/sd-image/nixos-sd-image-*.img
```

## Keep a local copy in this repo (optional)

Nix build outputs live in `/nix/store`, and `-o result-*` creates a symlink to
that store path. If you want a normal image file inside this project (for sync
across machines, backups, etc), copy it out of the store:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4
scripts/export-sd-image result-rpi3 sd-image rpi3
```

If you also want the uncompressed `.img` (bigger, but directly flashable), add
`--decompress`:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4 --decompress
scripts/export-sd-image result-rpi3 sd-image rpi3 --decompress
```

## Flash the SD card

Use your preferred imaging tool. Example with `dd`:

```bash
sudo dd if=./result/sd-image/nixos-sd-image-*.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Replace `/dev/sdX` with the correct device.

## Inject SSH public key (manual)

### Fully automated (recommended)

If you want provisioning to be repeatable without modifying SD cards after flashing,
set the admin public key(s) in `nix-pi-private/modules/shared.nix`, then rebuild
with the private flake override and flash the image. With
`lab.adminAuthorizedKeys` set, the image will include
`/etc/ssh/authorized_keys/<adminUser>` automatically.

### Manual injection (fallback)

Mount the root partition from the SD card and add the public key file:

```text
/etc/ssh/authorized_keys/<adminUser>
```

Where `<adminUser>` is the configured admin username (default: `admin`, or your
private override via `lab.adminUser`).

If you are unsure which username was built into the image, you can place the
same key for both `admin` and your preferred user.

The key file must contain the contents of:

```text
~/.ssh/id_ed25519.pub (or your preferred public key)
```

Note: the SD card root partition is typically an ext4 filesystem owned by
`root:root`, so creating `/etc/ssh/authorized_keys` and writing the key file
usually requires `sudo` on the host while the SD card is mounted.

For the exact commands used in your local environment (mount points, key path,
IP), keep a local runbook under `private/` (gitignored).

Helper script (recommended):

```bash
scripts/inject-ssh-key <root-mount> <public-key-path> --user <adminUser>
```

This works because OpenSSH is configured to read keys from
`/etc/ssh/authorized_keys/%u`. The build allows empty keys, so injecting this
file is required to avoid lockout.

## First boot

- Boot each Pi from its SD card.
- Wait for DHCP to assign an IP.
- Reserve the IP address in the router.
- SSH in using the IP address.
- If you reflashed the Pi, you may need to remove a stale SSH host key:
  `ssh-keygen -R <ip>`

After first boot, set the hostname on each node (example):

```bash
sudo hostnamectl set-hostname <hostname>
```

## Secrets bootstrap (sops-nix)

Secrets are provisioned at activation/boot to `/run/secrets` (tmpfs). Each host
must have its own age private key present on disk (outside Git and outside the
Nix store) for decryption to work.

One-time bootstrap helper:

```bash
scripts/bootstrap-sops-age-key <source-host> <target-host> [target-host...]
```

Example:

```bash
scripts/bootstrap-sops-age-key pi-node-a pi-node-b pi-node-c
```

Run this before the first rebuild that depends on SOPS secrets on a target host.

See `docs/lifecycle/SECRETS.md`.

## Cross-machine sync

This repo is synced across machines via a file sync tool. Avoid host-specific
permissions or files that cause conflicts across machines.

## Remote builder identities

If a host is used as a remote builder for another host, keep its Nix signing
identity recoverable outside Git so the same trust relationship can be restored
after rebuild or replacement.

Use `scripts/bootstrap-nix-signing-key` to restore an existing builder identity
onto a rebuilt host, then rebuild declaratively.

See `docs/lifecycle/REMOTE_BUILDS.md`.
