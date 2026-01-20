# Pi Provisioning

This document defines the repeatable workflow for preparing NixOS SD cards for
`pi-node-*` devices. The goal is to minimize manual steps on the Pis.

## Assumptions

- Host machine: Ubuntu 25.10 x86_64 with Nix installed and flakes enabled.
- Network: DHCP only; IPs will be reserved after first boot.
- Access: SSH keys are injected into the SD image before first boot.
- Admin user: `admin` (member of `docker` group); override in private config.

## Private overrides (recommended)

Create `nixos/hosts/private/overrides.nix` to store sensitive values (usernames,
domains, or hostnames). This path is gitignored. See
`nixos/hosts/private/README.md` for an example.
For hostnames, create a private file per node (for example `pi-node-01.nix`).

## Build the SD image

Build an image per host using the flake output:

```bash
nix build .#nixosConfigurations.pi-node-01.config.system.build.sdImage
```

Repeat for `pi-node-02` and `pi-node-03` as needed.

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

## Flash the SD card

Use your preferred imaging tool. Example with `dd`:

```bash
sudo dd if=./result/sd-image/nixos-sd-image-*.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Replace `/dev/sdX` with the correct device.

## Inject SSH public key (manual)

Mount the root partition from the SD card and add the public key file:

```text
/etc/ssh/authorized_keys/admin
```

The key file must contain the contents of:

```text
~/.ssh/id_ed25519.pub (or your preferred public key)
```

This works because OpenSSH is configured to read keys from
`/etc/ssh/authorized_keys/%u`. The build allows empty keys, so injecting this
file is required to avoid lockout.

## First boot

- Boot each Pi from its SD card.
- Wait for DHCP to assign an IP.
- Reserve the IP address in the router.
- SSH in using the IP address.

## Cross-machine sync

This repo is synced across machines via a file sync tool. Avoid host-specific
permissions or files that cause conflicts across machines.
