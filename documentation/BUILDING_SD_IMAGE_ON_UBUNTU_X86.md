# Building a NixOS Raspberry Pi SD image on Ubuntu (x86_64) with QEMU (aarch64)

This repo can build a bootable NixOS SD image for Raspberry Pi (ARM64 / `aarch64-linux`) from an x86_64 Ubuntu workstation, using QEMU user emulation via `binfmt_misc`.

The end result is a `*.img` or `*.img.zst` you can flash to an SD card, boot the Pi, and SSH in immediately.

## 0) Prerequisites (Ubuntu host)

You need:

- Nix installed (multi-user / `nix-daemon` recommended on Ubuntu)
- QEMU user emulation + binfmt registration for `aarch64`

### Install QEMU + binfmt

On Ubuntu:

```bash
sudo apt update
sudo apt install -y qemu-user-static binfmt-support
```

Verify QEMU is present:

```bash
command -v qemu-aarch64-static qemu-aarch64
```

Verify binfmt is enabled and the aarch64 handler exists:

```bash
cat /proc/sys/fs/binfmt_misc/status
ls /proc/sys/fs/binfmt_misc | rg qemu-aarch64 || true
```

If `/proc/sys/fs/binfmt_misc` does not exist, mount it:

```bash
sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
```

## 1) Repo files you must edit

### A) Put your SSH public key into the host config

Create `local/authorized-keys.nix` from the example and add your real public keys:

- `local/authorized-keys.nix.example` → `local/authorized-keys.nix`

This file is ignored by git so you can keep a public repository.

To print your public key from a private key:

```bash
ssh-keygen -y -f ~/.ssh/<your_private_key>
```

### B) Ensure the SD-image module targets aarch64 (Pi 3/4 64-bit)

For a 64-bit Raspberry Pi SD image, this repo uses:

- `hosts/rpi-box-03/sd-image.nix`

It must import the aarch64 SD-image module from nixpkgs:

- `.../installer/sd-card/sd-image-aarch64.nix`

In nixpkgs `24.05`, the `sd-image-raspberrypi.nix` module targets 32-bit Pis and selects a 32-bit downstream kernel, which fails for `aarch64-linux`. This repo is already configured to use `sd-image-aarch64.nix` for `rpi-box-03-sd`.

## 2) Configure the Nix daemon for aarch64 builds (Ubuntu)

By default, a multi-user Nix daemon on x86_64 will refuse to build `aarch64-linux` derivations:

> Required system: `aarch64-linux` … Current system: `x86_64-linux`

Fix this by editing `/etc/nix/nix.conf` and restarting `nix-daemon`.

### Edit `/etc/nix/nix.conf`

```bash
sudoedit /etc/nix/nix.conf
```

Add (or ensure) these lines:

```conf
build-users-group = nixbld
extra-platforms = aarch64-linux i686-linux x86_64-v1-linux x86_64-v2-linux x86_64-v3-linux
trusted-users = root <your-username>
```

Recommended for QEMU builds on Ubuntu:

```conf
sandbox = false
```

Why: when sandboxing is enabled, the sandbox may not have access to `/usr/bin/qemu-aarch64-static`, causing aarch64 build steps to fail even if `binfmt_misc` is registered.

### Restart `nix-daemon`

```bash
sudo systemctl restart nix-daemon
```

Verify:

```bash
nix config show | rg 'extra-platforms|trusted-users|sandbox'
```

## 3) Build the SD image

From the repo root:

```bash
nix build .#nixosConfigurations.rpi-box-03-sd.config.system.build.sdImage
```

Pi 4 SD image:

```bash
nix build .#nixosConfigurations.rpi-box-01-sd.config.system.build.sdImage
```

The output is in:

- `./result/sd-image/`

Often it is compressed (`*.img.zst`).

## 4) Flash the image to an SD card

### If the image is compressed

Note: `./result` points into `/nix/store` (read-only), so you can’t decompress “in place”.

Decompress to a writable path:

```bash
mkdir -p ./out
zstd -d -c ./result/sd-image/*.img.zst > ./out/nixos-sd-image.img
```

### Write to the SD card

Identify your SD device (example only):

```bash
lsblk
```

Flash (replace `/dev/sdX` with your SD card device):

```bash
sudo dd if=./out/nixos-sd-image.img of=/dev/sdX bs=4M conv=fsync status=progress
```

## 5) First boot + SSH

1. Insert SD card into the Pi
2. Connect Ethernet (DHCP is enabled by this repo’s modules)
3. Power on and wait ~1 minute
4. Find the Pi IP from your router/DHCP lease list (or try `rpi-box-03.local` if mDNS works)

SSH in:

```bash
ssh root@<pi-ip>
```

Or use the non-root user (if configured):

```bash
ssh pi@<pi-ip>
```

## Notes / troubleshooting

### Locale warning (`setlocale: LC_ALL: cannot change locale (en_IE.UTF-8)`)

If you see warnings like:

```text
bash: warning: setlocale: LC_ALL: cannot change locale (en_IE.UTF-8)
```

It usually means your shell sets `LC_ALL`/`LANG` to a locale that isn’t generated on Ubuntu.
Fix by generating the locale or by using a locale that exists on your host.
