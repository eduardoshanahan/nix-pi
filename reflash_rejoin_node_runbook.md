# Reflash & Rejoin Node Runbook

**Phase:** 2 (Safety Net)

**Purpose:**
Provide a deterministic, low-stress procedure to recover a Raspberry Pi node
by reflashing its SD card and rejoining it to the homelab.

This runbook assumes **no local console / HDMI access** and relies entirely on
SSH and declarative NixOS configuration.

---

## When to Use This Runbook

Use this procedure if **any** of the following occur:

- SD card corruption or filesystem errors
- Node fails to boot or becomes unreachable
- Irrecoverable configuration mistake
- Hardware replacement
- Trust reset ("I want to be 100% sure this node is clean")

If the node is still reachable and stable, prefer a rollback instead.

---

## Preconditions

- [ ] Node configuration exists in git (flake-based)
- [ ] SSH public key is available locally
- [ ] Network allows temporary DHCP for first boot
- [ ] Static IP for the node is documented
- [ ] Another node (or laptop) is available to perform flashing

If any precondition is missing → **STOP** and resolve it first.

---

## Step 0 — Identify the Node

Goal: eliminate ambiguity before flashing anything.

Actions:

- [ ] Identify the physical Raspberry Pi (label, serial, or location)
- [ ] Confirm hostname as defined in git (e.g. `rpi-box-01`)
- [ ] Confirm intended static IP address and subnet
- [ ] List services expected on this node (Traefik, Pi-hole, none)
- [ ] Confirm this node is safe to take offline

Verification:

- [ ] Host entry exists in flake (`nixosConfigurations.<hostname>`)
- [ ] Static IP matches documentation

Failure signals:

- Hostname/IP unclear or duplicated → STOP and resolve naming first

---

## Step 1 — Prepare the SD Card Image

Goal: produce a clean, bootable SD card for the correct architecture.

Actions (Linux/macOS):

- [ ] Download the **aarch64-linux** NixOS SD image you’ve standardized on
- [ ] Verify checksum against the published SHA256 (don’t skip)
- [ ] Decompress if needed:

```bash
unzstd -c nixos-sd-image-aarch64-linux.img.zst > nixos.img
```

- [ ] Identify the SD device path **carefully**:

```bash
lsblk   # Linux
# or
 diskutil list  # macOS
```

- [ ] Flash the image:

```bash
sudo dd if=nixos.img of=/dev/sdX bs=4M conv=fsync status=progress
# macOS example:
# sudo dd if=nixos.img of=/dev/rdiskN bs=4m conv=sync
```

- [ ] Eject and re-insert the SD card so partitions mount cleanly.

Verification:

- [ ] `dd` finishes without I/O errors
- [ ] After re-insert, you can see **two partitions** (boot + root)
- [ ] Boot partition mounts and contains expected boot files

Rollback:

- Reflash (always allowed).

---

## Step 2 — Inject Minimal Bootstrap Configuration

Goal: ensure **first boot is reachable over SSH** using **temporary DHCP**.

WARNING: Bootstrap should be minimal:

- SSH enabled
- your SSH public key authorized
- DHCP on
- optional: create an admin user + passwordless sudo (temporary)

Actions:

- [ ] Mount partitions (example Linux):

```bash
sudo mkdir -p /mnt/nixos-boot /mnt/nixos-root
sudo mount /dev/sdX1 /mnt/nixos-boot
sudo mount /dev/sdX2 /mnt/nixos-root
```

- [ ] Confirm `/mnt/nixos-root/etc/nixos/` exists (create it if missing):

```bash
sudo mkdir -p /mnt/nixos-root/etc/nixos
```

- [ ] Create a minimal `/mnt/nixos-root/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, lib, ... }:
{
  networking.hostName = "REPLACE_ME";
  networking.useDHCP = lib.mkDefault true;

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  users.users.eduardo = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY"
    ];
  };

  security.sudo.wheelNeedsPassword = false; # optional, temporary convenience

  # Helpful discovery during bootstrap
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
}
```

- [ ] Unmount cleanly:

```bash
sync
sudo umount /mnt/nixos-boot /mnt/nixos-root
```

Verification:

- [ ] `configuration.nix` exists on the SD root filesystem
- [ ] Your **public** SSH key is present (never a private key)
- [ ] DHCP is enabled for first boot

Failure signals:

- Missing `/etc/nixos/configuration.nix`
- SSH not enabled
- DHCP disabled before first boot

Rollback:

- Re-mount and fix the bootstrap config, or reflash.

---

## Step 3 — First Boot & Discovery

Goal: power on the node, obtain an IP address, and establish first SSH access.

Actions:

- [ ] Insert the prepared SD card into the Raspberry Pi
- [ ] Connect Ethernet (avoid Wi-Fi for first boot)
- [ ] Power on the node
- [ ] Wait 60–120 seconds for first boot (can be slow)

Discovery methods (use in this order):

1. **Router / UCG client list**
   - Look for a new client with hostname set in bootstrap config
   - Note the assigned IP address

1. **mDNS (if Avahi enabled)**

```bash
ping <hostname>.local
```

1. **ARP scan from another LAN host**

```bash
arp -a | grep -i <hostname>
# or
sudo nmap -sn 198.51.100.0/24
```

Actions (SSH):

- [ ] Attempt SSH using the discovered IP:

```bash
ssh eduardo@<ip-address>
```

Verification:

- [ ] SSH connection succeeds without password prompt
- [ ] Hostname matches expected value
- [ ] `ip a` shows an address assigned via DHCP

Failure signals:

- Node does not appear in router client list after 2–3 minutes
- `ssh` times out or refuses connection
- Password prompt appears (key not applied)

Recovery:

- Power off the node
- Re-mount SD card on another machine
- Re-check Step 2 (bootstrap configuration)
- Reflash if unsure

---

## Step 4 — Apply Declarative Configuration

Goal: replace the temporary bootstrap state with the fully declarative homelab configuration.

WARNING: This step transitions the node from **DHCP → static IP** and from **bootstrap → managed state**.
Proceed deliberately.

Actions:

- [ ] Ensure you are SSHed into the node via the **DHCP-assigned IP**
- [ ] Clone the homelab repository:

```bash
cd ~
git clone https://github.com/eduardoshanahan/nix-pi.git
cd nix-pi
```

- [ ] Verify repository state:

```bash
git status
git rev-parse HEAD
```

- [ ] Identify the correct host configuration (e.g. `rpi-box-01`)
- [ ] Inspect host config for:
  - hostname
  - static IP address
  - enabled services

- [ ] Build and apply the configuration:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

WARNING: **Do not close the SSH session during the build.**

Verification (during build):

- [ ] Evaluation completes without errors
- [ ] Build completes successfully
- [ ] Services are activated without failures

Verification (after build):

- [ ] Hostname updates correctly (`hostnamectl`)
- [ ] Static IP is applied:

```bash
ip a
ip route
```

- [ ] Node is reachable on the **static IP** from another host

WARNING: At this point, the original DHCP IP may disappear.

Rollback:

- If SSH disconnects mid-build: wait 60s, reconnect via static IP
- If build fails before network switch: fix config and re-run
- If network becomes unreachable: reflash and restart runbook

---

## Step 5 — Rejoin Services

Goal: ensure the node cleanly rejoins the homelab and all declared services are active and reachable.

Actions:

- [ ] Confirm system reached the default target:

```bash
systemctl get-default
systemctl is-system-running
```

- [ ] Verify firewall is enabled and loaded:

```bash
sudo systemctl status firewall
sudo nft list ruleset
```

- [ ] Verify Traefik (if present on this node):

```bash
systemctl status traefik
journalctl -u traefik --since "-5m"
```

- [ ] Verify Pi-hole (if present on this node):

```bash
systemctl status pihole
# or, if containerized:
docker ps
journalctl -u pihole --since "-5m"
```

- [ ] Verify secrets are present (runtime only):

```bash
ls -la /run/secrets
```

Verification:

- [ ] All declared services are **active / running**
- [ ] No repeated restart loops
- [ ] Secrets exist only under `/run/secrets`
- [ ] No secrets present in `/nix/store`

Network verification:

- [ ] Node reachable via static IP
- [ ] Services reachable from another host (HTTP/DNS as applicable)

Failure signals:

- Service stuck in activating / failed state
- Missing secrets under `/run/secrets`
- Traefik or Pi-hole repeatedly restarting

Recovery:

- Inspect service logs
- Fix declarative config
- Re-run `nixos-rebuild switch`
- If state is unclear → reflash and restart runbook

---

## Step 6 — Post-Rejoin Validation

Goal: confirm the node is indistinguishable from its pre-failure state and safe to rely on.

Actions:

- [ ] Compare node configuration against a healthy peer (if available)
- [ ] Verify hostname, static IP, and routing are correct
- [ ] Confirm no unexpected open ports:

```bash
ss -tulpen
```

- [ ] Verify DNS behavior (if Pi-hole present):

```bash
dig example.com @<node-static-ip>
```

- [ ] Verify HTTP ingress (if Traefik present):
  - Access a known service route from another host

- [ ] Review system logs for warnings or errors:

```bash
journalctl -p warning..alert --since "-30m"
```

- [ ] Observe the node for ≥30 minutes under normal idle load

Verification:

- [ ] Network behavior matches expectations
- [ ] No recurring warnings or errors
- [ ] Services remain healthy over time
- [ ] Node behaves identically to peers

Failure signals:

- Intermittent service failures
- Repeated warnings in logs
- Unexpected traffic or open ports

Recovery:

- Identify offending service or config
- Fix declaratively and rebuild
- If trust is lost → reflash and restart runbook

---

## Runbook Completion Criteria

The runbook is complete when **all** are true:

- [ ] Node reachable via SSH on static IP
- [ ] All declared services running
- [ ] Firewall active and correct
- [ ] Secrets present only at runtime
- [ ] No unexplained errors after observation period

At this point, the node is safe to reintroduce into higher-risk phases (DNS/DHCP).

---

**Status:** Draft
**Owner:** Homelab
**Next document:** Backup Strategy
