# Raspberry Pi NixOS Project Plan

This document is a **step-by-step project plan** to deploy **NixOS on a Raspberry Pi**, bootstrapped from your workstation, using an **SD card image** and then managed remotely.

This plan assumes:

- Workstation: **Ubuntu x86_64**
- Target: **Raspberry Pi 3 / Pi 4 (aarch64)**
- SD images are built locally using **QEMU/binfmt** (not downloaded)

Ubuntu setup and a complete “build SD image on x86_64” walkthrough:

- `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md`
- `documentation/getting nix ready.md`

The goal is:

- Flash once
- Configure declaratively
- Never SSH in to "fix" things
- Manage everything from your workstation

---

## 1. Project goals

This project assumes **multiple Raspberry Pis**, all running **NixOS**, and **Docker is the standard runtime for applications**.

- Raspberry Pi runs **NixOS (headless)**
- Network and SSH work on first boot
- Configuration is written on the workstation
- Deployment is done via `nixos-rebuild --target-host`
- No Ansible needed after bootstrap
- Configuration lives in Git

---

## 2. What you need

### Hardware

- Raspberry Pi (Pi 3 / Pi 4 / Zero 2)
- SD card (16–32 GB recommended)
- Ethernet cable (recommended for first boot)

### Workstation

- Ubuntu x86_64
- Nix installed (multi-user daemon)
- QEMU user emulation + binfmt for `aarch64`
- SSH key pair (`~/.ssh/id_ed25519`)
- VS Code (or preferred editor)

---

## 3. Repository structure (recommended)

Create a Git repository on your workstation:

```text
pi-nixos/
├── flake.nix
├── hosts/
│   └── pi.nix
├── modules/
│   ├── common.nix
│   └── networking.nix
└── README.md
```

This repo is the **single source of truth** for the Pi.

---

## 4. Build and flash a custom SD image (recommended)

Downloading prebuilt official images on an x86_64 workstation is not always convenient/reliable (and won’t include your SSH keys).

Instead, build a custom SD image from this repo so SSH works on first boot.

If you have not already configured Nix + QEMU on Ubuntu, do that first:

- `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md`

### 4.1 Configure your SSH key in the host files

Edit:

- `hosts/rpi-box-03/default.nix` (for Pi 3)
- `hosts/rpi-box-01/default.nix` (for Pi 4)

Update:

- `users.users.root.openssh.authorizedKeys.keys`
- `users.users.pi.openssh.authorizedKeys.keys`

To print your public key from a private key:

```bash
ssh-keygen -y -f /home/eduardo/.ssh/eduardo-hhlab
```

### 4.2 Build the SD image (Pi 3 or Pi 4)

Pi 3:

```bash
nix build .#nixosConfigurations.rpi-box-03-sd.config.system.build.sdImage
```

Pi 4:

```bash
nix build .#nixosConfigurations.rpi-box-01-sd.config.system.build.sdImage
```

The output is under `./result/sd-image/` and is typically `*.img.zst`.

If you are building on Ubuntu x86_64, follow `documentation/BUILDING_SD_IMAGE_ON_UBUNTU_X86.md` to configure QEMU + Nix for aarch64 builds.

### 4.3 Decompress and flash

Because `./result` points into `/nix/store` (read-only), decompress to a writable directory:

```bash
mkdir -p ./out
zstd -d -c ./result/sd-image/*.img.zst > ./out/nixos-sd-image.img
```

Flash it (replace `/dev/sdX` carefully):

```bash
sudo dd if=./out/nixos-sd-image.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

---

## 5. Preconfigure NixOS on the SD card (bootstrap step)

You will typically see:

- A **boot (FAT)** partition
- A **root (ext4)** partition

### Reality check (why “edit `/etc/nixos/configuration.nix` on the SD card” often doesn’t work)

Many NixOS Raspberry Pi SD images do **not** contain a writable `/etc/nixos` on the SD card. Instead, the system configuration is baked into the Nix store, and the root partition may only contain `/boot` and `/nix`.

If your mounted root looks like this:

```text
/boot
/nix
/nix-path-registration
```

…then you *cannot* “just edit `/etc/nixos/configuration.nix` on the SD card” to add SSH keys.

### Recommended bootstrap: build a custom SD image with your SSH key baked in

This plan uses the repo-built SD images from section 4 (instead of trying to edit `/etc/nixos` on the SD card or relying on a downloaded image).

---

## 6. First boot (SSH)

1. Insert SD card into the Pi
2. Connect Ethernet
3. Power on
4. Wait ~1 minute

From your workstation:

```bash
ssh -i /home/eduardo/.ssh/eduardo-hhlab -o IdentitiesOnly=yes root@<pi-ip>
```

If SSH works, the bootstrap is complete.

---

## 7. Take over from the workstation (normal workflow)

From now on:

- **Do not edit files on the Pis**
- All changes happen on the workstation
- Docker is used for applications
- NixOS manages the host and Docker itself

The Pis are treated as a small fleet.

From now on:

- **Do not edit files on the Pi**
- All changes happen in Git

Deploy with:

```bash
nixos-rebuild switch \
  --target-host root@<pi-ip> \
  --flake .#pi
```

This is:

- Atomic
- Reversible
- Repeatable

---

## 8. Example `flake.nix`

This flake supports **multiple Raspberry Pis**, each with its own configuration, while sharing common modules.

```nix
{
  description = "Raspberry Pi NixOS configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.pi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hosts/pi.nix
      ];
    };
  };
}
```

---

## 9. Writing per-Pi configurations (`hosts/*.nix`)

Each Raspberry Pi has its own host file, but they all share a common Docker-based application model.

```nix
{ config, pkgs, ... }:

{
  networking.hostName = "rpi-box-01";

  time.timeZone = "UTC";

  services.openssh.enable = true;

  users.users.pi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA...your-public-key"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "24.05";
}
```

---

## 10. Rollbacks and recovery

If something goes wrong:

- Reboot the Pi
- Choose a previous generation in the boot menu

You almost cannot brick the device.

---

## 11. When to add more

After the multi-Pi Docker setup is stable, you can add:

- Per-Pi Docker Compose files
- Image version pinning
- Central logging / monitoring
- Secrets management for containers
- CI that builds Docker images

Only after this works:

- Wi-Fi configuration
- Secrets management
- Services (Docker, Home Assistant, etc.)
- Multiple Pis from the same repo

---

## 12. Mental model (important)

- SD card = hardware bootstrap
- Git repo = system definition
- Workstation = control plane
- Pi = declarative target

You are not administering machines anymore.
You are **describing systems**.

---

## 13. Done

At this point you have:

- A reproducible Raspberry Pi
- A clean bootstrap flow
- A scalable pattern for more devices

This same model extends to VPSes and servers.
