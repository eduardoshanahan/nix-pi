# Pi Provisioning (RPi 3 + RPi 4)

This document defines the repeatable, headless workflow for preparing NixOS SD
cards for Raspberry Pi devices. The goal is to minimize manual steps on the Pis
while keeping secrets out of Git.

## Assumptions

- Host machine: Ubuntu 25.10 x86_64 with Nix installed and flakes enabled.
- Network: DHCP only; IPs will be reserved after first boot.
- Access: SSH public key is injected onto the SD card before first boot.
- Admin user: configured via `lab.adminUser` (default is `admin`).

## Private overrides (recommended)

Create `nixos/hosts/private/overrides.nix` to store sensitive values (usernames,
domains, or hostnames). This path is gitignored. See
`nixos/hosts/private/README.md` for an example.
For hostnames, prefer setting them after first boot. If you do want per-host
images later, you can create a private file per node (for example
`<hostname>.nix`) and build per-host outputs in your own fork if desired.

## Build the SD image

### Important: private overrides and flakes

This repo keeps `nixos/hosts/private/` gitignored. If you build with
`nix build .#...` from a Git working tree, Nix treats the flake source as the
*tracked* Git tree, so gitignored/untracked private overrides may not be visible
during evaluation.

If you need `nixos/hosts/private/overrides.nix` (for example to set
`lab.adminUser = "<adminUser>";`) to be included in the build, use a path-based
flake reference:

```bash
nix build path:.#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
nix build path:.#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

### Recommended builds (one image per architecture)

RPi 4 (aarch64):

```bash
nix build path:.#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
```

RPi 3 (recommended: 64-bit aarch64 for better cache coverage and faster builds
on x86):

```bash
nix build path:.#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

Optional: RPi 3 in 32-bit mode (armv7l). Much slower on x86 hosts and may require
`--impure` and `NIXPKGS_ALLOW_BROKEN=1`:

```bash
NIXPKGS_ALLOW_BROKEN=1 nix build --impure path:.#nixosConfigurations.rpi3-armv7l.config.system.build.sdImage -o result-rpi3
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
set the admin public key(s) in your gitignored `nixos/hosts/private/overrides.nix`:

```nix
{ ... }:
{
  lab.adminUser = "<adminUser>";
  lab.adminAuthorizedKeys = [
    "ssh-ed25519 AAAA... comment"
  ];
}
```

Then rebuild using `path:.#...` (so the private overrides are included) and
flash the image. With `lab.adminAuthorizedKeys` set, the image will include
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

## Cross-machine sync

This repo is synced across machines via a file sync tool. Avoid host-specific
permissions or files that cause conflicts across machines.
