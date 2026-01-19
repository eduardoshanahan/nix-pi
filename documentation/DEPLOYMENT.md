# Deployment design (Pis)

This document defines how the fleet is deployed and updated, aligned with:

- Workstation is the control plane
- Git is the source of truth
- `nixos-rebuild` performs deployments
- No imperative edits on Pis after bootstrap

## 1) Connectivity and identity

Recommended baseline:

- Assign each Pi a unique hostname: `rpi-box-01`, `rpi-box-02`, `rpi-box-03`, …
- Create DHCP reservations in your router so IPs are stable
- Bootstrap phase (no DNS yet): deploy using IPs (or temporary `/etc/hosts`)
- Steady state: use DNS names (Pi-hole local DNS)

Fallback (optional):

- Enable mDNS/Avahi (already enabled in `modules/networking.nix`) so `rpi-box-01.local` works on many networks.

## 2) Bootstrap (once per Pi)

Bootstrap goal: “SSH works on first boot”.

Using the official NixOS Raspberry Pi (aarch64) SD image:

- Enable DHCP
- Enable SSH
- Add your workstation SSH public key for `root`
- Set `networking.hostName`

After SSH works, the SD card should not be modified again.

## 3) Hardware configuration capture (once per Pi)

Your flake-managed configuration should include the Pi’s `hardware-configuration.nix`.

Workflow:

- `./scripts/pull-hardware rpi-box-01 root@<pi-ip>`

This copies `/etc/nixos/hardware-configuration.nix` from the Pi into `hosts/rpi-box-01/hardware-configuration.nix`.

## 4) Deployment workflow (normal operations)

Use `nixos-rebuild` from the workstation:

- `./scripts/deploy rpi-box-01 root@<pi-ip>`

By default the script sets `--build-host` equal to the target host (build on the Pi). This avoids cross-compiling aarch64 on an x86_64 workstation.

If you have an aarch64 builder, override:

- `BUILD_HOST=<ssh-host> ./scripts/deploy rpi-box-01 root@<pi-ip>`

To build on the workstation (if it can build aarch64), use:

- `BUILD_HOST=local ./scripts/deploy rpi-box-01 root@<pi-ip>`

## 5) DNS transition plan (UniFi DHCP → Pi-hole DNS)

This deployment is designed to work in two phases.

### Phase A: initial bring-up (no DNS dependency)

- Use UniFi DHCP reservations to make each Pi’s IP stable.
- Deploy using IPs explicitly:
  - `./scripts/deploy rpi-box-03 root@<pi-ip>`
- Optionally add temporary workstation-only mappings (if you want names immediately):
  - `/etc/hosts`: `<pi-ip> rpi-box-03`

### Phase B: steady state (Pi-hole provides local DNS)

Once Pi-hole is running on a Pi with a stable IP:

- Add Local DNS records in Pi-hole (e.g. `rpi-box-03 -> <pi-ip>`).
- Track the current host ↔ IP mapping in `documentation/ip-addresses.local.md` (see `documentation/ip-addresses.md` template).
- Update UniFi DHCP “DHCP Name Server” (option 6) to hand out the Pi-hole IP as DNS.

Practical note: avoid configuring a “secondary DNS” that is not Pi-hole if you want blocking to be consistent (many clients will bypass Pi-hole when the secondary responds faster). If you need redundancy, run a second Pi-hole.

## 6) Updating Nixpkgs and rolling out changes

- Change NixOS config in this repo
- Update inputs (lock file) when you choose to upgrade
- Deploy to one Pi first, then the rest

Rollbacks are available via NixOS generations (and boot menu).

## 7) Adding a new Pi

1. Create `hosts/rpi-box-NN/default.nix` (copy from `hosts/rpi-box-01/default.nix`)
2. Add the host to `flake.nix`
3. Bootstrap SD + SSH
4. `./scripts/pull-hardware pi-N root@<pi-ip>`
5. `./scripts/deploy pi-N root@<pi-ip>`
