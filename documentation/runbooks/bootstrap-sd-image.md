# Runbook: Bootstrap SD image

Goal: build and flash an SD image that boots NixOS and allows SSH on first boot.

## Prereqs (workstation)

- Nix installed with flakes enabled.
- If building `aarch64-linux` images on x86_64 Ubuntu: QEMU/binfmt configured.
  - See `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md`.

## 1) Choose the target

This repo has SD image targets for:

- Pi 3: `rpi-box-03-sd`
- Pi 4: `rpi-box-01-sd`

## 2) Ensure SSH keys are configured

Create `local/authorized-keys.nix` from the example and add your real public keys:

- `local/authorized-keys.nix.example` → `local/authorized-keys.nix`

This file is ignored by git so you can keep a public repository.

## 3) Build the image

Pi 3:

```bash
nix build .#nixosConfigurations.rpi-box-03-sd.config.system.build.sdImage
```

Pi 4:

```bash
nix build .#nixosConfigurations.rpi-box-01-sd.config.system.build.sdImage
```

## 4) Decompress (if needed)

The output is under `./result/sd-image/` and is often `*.img.zst`.

```bash
mkdir -p ./out
zstd -d -c ./result/sd-image/*.img.zst > ./out/nixos-sd-image.img
```

## 5) Flash to SD

Identify the SD device:

```bash
lsblk
```

Flash (replace `/dev/sdX` carefully):

```bash
sudo dd if=./out/nixos-sd-image.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

## 6) Verify (first boot)

- Boot the Pi with Ethernet connected.
- Find its IP from DHCP leases.
- SSH in:

```bash
ssh root@<pi-ip>
```
