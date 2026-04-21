# Operations Guide

Quick reference for investigating and maintaining the homelab from a fresh session.

---

## Lab topology

| Host | IP | Role | Builder |
|------|----|------|---------|
| rpi-box-01 | 192.0.2.10 | User apps (Pi-hole, media tools, self-hosted apps) | Self |
| rpi-box-02 | 192.0.2.10 | Monitoring, home automation, heavy services | Self |
| rpi-box-03 | 192.0.2.10 | DNS (Pi-hole primary), Loki, Promtail syslog | rpi-box-02 |
| nas-host | `nas-lan-ip` | Synology NAS | n/a |

## SSH access

```bash
ssh rpi-box-01
ssh rpi-box-02
ssh rpi-box-03
ssh nas-host
```

---

## Deploying a box

All commands run from `nix-pi/`. The local `nix-services` and `nix-pi-private` directories
are passed as path overrides so uncommitted changes take effect immediately.

```bash
# rpi-box-01 (builds on itself)
nixos-rebuild switch \
  --flake path:$PWD#rpi-box-01 \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@rpi-box-01 \
  --build-host eduardo@rpi-box-01 \
  --sudo

# rpi-box-02 (builds on itself)
nixos-rebuild switch \
  --flake path:$PWD#rpi-box-02 \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@rpi-box-02 \
  --build-host eduardo@rpi-box-02 \
  --sudo

# rpi-box-03 (builds on rpi-box-02 — rpi3 is too slow to build for itself)
nixos-rebuild switch \
  --flake path:$PWD#rpi-box-03 \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@rpi-box-03 \
  --build-host eduardo@rpi-box-02 \
  --sudo
```

> **rpi-box-03 prerequisite**: rpi-box-02 must have its Nix signing key at
> `/etc/nix/rpi-box-02-priv.pem` and rpi-box-03 must trust the matching public key
> (`rpi-box-02:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=`).
> See `PROVISIONING_LOCAL.md` for bootstrap steps.

---

## Config file locations

All per-host config lives in `nix-pi-private/modules/<host>.nix`.
Service modules are in `nix-services/services/<service>/`.

| What | Where |
|------|-------|
| rpi-box-01 host config | `nix-pi-private/modules/rpi-box-01.nix` |
| rpi-box-02 host config | `nix-pi-private/modules/rpi-box-02.nix` |
| rpi-box-03 host config | `nix-pi-private/modules/rpi-box-03.nix` |
| Shared lab config | `nix-pi-private/modules/shared.nix` |
| Loki service | `nix-services/services/loki/` |
| Prometheus config | `nix-services/services/prometheus/` |
| Alertmanager config | `nix-services/services/alertmanager/` |

---

## Quick health check (all boxes)

```bash
# Are all boxes reachable?
for h in rpi-box-01 rpi-box-02 rpi-box-03; do
  echo -n "$h: "; ssh $h uptime 2>&1 | tail -1
done

# What's running on a box?
ssh rpi-box-01 "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Any failed systemd units?
ssh rpi-box-01 "systemctl --failed --no-pager"

# Memory pressure?
ssh rpi-box-01 "free -h && swapon --show"

# Disk space?
ssh rpi-box-03 "df -h /srv"
```

---

## Investigating a firing alert

Alerts come from Prometheus on rpi-box-02, routed via Alertmanager → gmail → your inbox.

### TargetDown

The subject tells you the instance and job, e.g.:
`[FIRING:1] TargetDown rpi-box-01-metrics.internal.example:9100 nodes (critical)`

1. **Is the box reachable?**

   ```bash
   ssh rpi-box-01 uptime
   ```

   If not → check network/power. If yes → the service crashed, not the box.

2. **Is the service running?**

   ```bash
   # For node_exporter (port 9100):
   ssh rpi-box-01 "systemctl status prometheus-node-exporter"
   curl http://192.0.2.10:9100/metrics | head -5

   # For Loki (port 3100):
   ssh rpi-box-03 "systemctl status loki; docker ps | grep loki"
   curl http://192.0.2.10:3100/ready
   ```

3. **Check recent logs:**

   ```bash
   ssh rpi-box-01 "journalctl -u prometheus-node-exporter -n 50 --no-pager"
   ssh rpi-box-03 "docker logs loki --tail 50"
   ```

4. **Check memory (common cause on rpi-box-03):**

   ```bash
   ssh rpi-box-03 "free -h; swapon --show; uptime"
   ```

### Common service → port mapping

| Alert instance | Service | Box | Check command |
|----------------|---------|-----|---------------|
| `rpi-box-01-metrics:9100` | node_exporter | rpi-box-01 | `systemctl status prometheus-node-exporter` |
| `rpi-box-02-metrics:9100` | node_exporter | rpi-box-02 | `systemctl status prometheus-node-exporter` |
| `rpi-box-03-metrics:9100` | node_exporter | rpi-box-03 | `systemctl status prometheus-node-exporter` |
| `loki:3100` | Loki | rpi-box-03 | `systemctl status loki; docker ps \| grep loki` |
| `rpi-box-01:8082` | Traefik metrics | rpi-box-01 | `docker ps \| grep traefik` |
| `rpi-box-01:9617` | pihole-exporter | rpi-box-01 | `docker ps \| grep pihole-exporter` |
| `rpi-box-01:8081` | cadvisor | rpi-box-01 | `docker ps \| grep cadvisor` |

---

## Known architecture notes

- **All services run as Docker containers** managed by NixOS systemd units
  (via `docker compose up -d`), except `node_exporter` and `pihole-FTL` which are
  native NixOS services.
- **rpi-box-03 has 894 MB RAM and no swap by default** — it was added 2026-03-23
  after Loki OOM'd. Swap is at `/var/swap` (2 GB). Loki is memory-limited to 256 MB.
- **rpi-box-03 uses rpi-box-02 as its Nix build host**. If rpi-box-02 is down or
  its signing key is missing, rpi-box-03 cannot be rebuilt.
- **Pi-hole**: rpi-box-03 is the primary DNS / sync source. rpi-box-01 and rpi-box-02
  sync from it twice daily.
- **Loki** lives on rpi-box-03 at port 3100. Promtail on all boxes pushes to it.
  Grafana on rpi-box-02 reads from it.
- **Prometheus and Alertmanager** run on rpi-box-02. Alerts are emailed via the
  smtp-relay container (Postfix, outbound via Gmail).

---

## Drift prevention

Config for each box lives in `nix-pi-private/modules/<host>.nix`.
If a service is imported but has no `services.X.enable = true` block, it defaults
to disabled and is a dead import — remove it to keep configs accurate.

After any manual change on a box (e.g. `docker restart`, editing a file), follow up
with a proper `nixos-rebuild switch` so the running state matches the declared config.
