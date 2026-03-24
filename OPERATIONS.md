# Operations Guide

Quick reference for investigating and maintaining the homelab from a fresh session.

---

## Lab topology

| Host | IP | Role | Builder |
|------|----|------|---------|
| pi-node-a | 192.0.2.10 | User apps (Pi-hole, media tools, self-hosted apps) | Self |
| pi-node-b | 192.0.2.10 | Monitoring, home automation, heavy services | Self |
| pi-node-c | 192.0.2.10 | DNS (Pi-hole primary), Loki, Promtail syslog | pi-node-b |
| nas-host | 192.0.2.x | Synology NAS | n/a |

## SSH access

```bash
ssh pi-node-a
ssh pi-node-b
ssh pi-node-c
ssh nas-host
```

---

## Deploying a box

All commands run from `nix-pi/`. The local `nix-services` and `nix-pi-private` directories
are passed as path overrides so uncommitted changes take effect immediately.

```bash
# pi-node-a (builds on itself)
nixos-rebuild switch \
  --flake path:$PWD#pi-node-a \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@pi-node-a \
  --build-host eduardo@pi-node-a \
  --sudo

# pi-node-b (builds on itself)
nixos-rebuild switch \
  --flake path:$PWD#pi-node-b \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@pi-node-b \
  --build-host eduardo@pi-node-b \
  --sudo

# pi-node-c (builds on pi-node-b — rpi3 is too slow to build for itself)
nixos-rebuild switch \
  --flake path:$PWD#pi-node-c \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@pi-node-c \
  --build-host eduardo@pi-node-b \
  --sudo
```

> **pi-node-c prerequisite**: pi-node-b must have its Nix signing key at
> `/etc/nix/pi-node-b-priv.pem` and pi-node-c must trust the matching public key
> (`pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=`).
> See `PROVISIONING_LOCAL.md` for bootstrap steps.

---

## Config file locations

All per-host config lives in `nix-pi-private/modules/<host>.nix`.
Service modules are in `nix-services/services/<service>/`.

| What | Where |
|------|-------|
| pi-node-a host config | `nix-pi-private/modules/pi-node-a.nix` |
| pi-node-b host config | `nix-pi-private/modules/pi-node-b.nix` |
| pi-node-c host config | `nix-pi-private/modules/pi-node-c.nix` |
| Shared lab config | `nix-pi-private/modules/shared.nix` |
| Loki service | `nix-services/services/loki/` |
| Prometheus config | `nix-services/services/prometheus/` |
| Alertmanager config | `nix-services/services/alertmanager/` |

---

## Quick health check (all boxes)

```bash
# Are all boxes reachable?
for h in pi-node-a pi-node-b pi-node-c; do
  echo -n "$h: "; ssh $h uptime 2>&1 | tail -1
done

# What's running on a box?
ssh pi-node-a "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Any failed systemd units?
ssh pi-node-a "systemctl --failed --no-pager"

# Memory pressure?
ssh pi-node-a "free -h && swapon --show"

# Disk space?
ssh pi-node-c "df -h /srv"
```

---

## Investigating a firing alert

Alerts come from Prometheus on pi-node-b, routed via Alertmanager → gmail → your inbox.

### TargetDown

The subject tells you the instance and job, e.g.:
`[FIRING:1] TargetDown pi-node-a-metrics.internal.example:9100 nodes (critical)`

1. **Is the box reachable?**

   ```bash
   ssh pi-node-a uptime
   ```

   If not → check network/power. If yes → the service crashed, not the box.

2. **Is the service running?**

   ```bash
   # For node_exporter (port 9100):
   ssh pi-node-a "systemctl status prometheus-node-exporter"
   curl http://192.0.2.10:9100/metrics | head -5

   # For Loki (port 3100):
   ssh pi-node-c "systemctl status loki; docker ps | grep loki"
   curl http://192.0.2.10:3100/ready
   ```

3. **Check recent logs:**

   ```bash
   ssh pi-node-a "journalctl -u prometheus-node-exporter -n 50 --no-pager"
   ssh pi-node-c "docker logs loki --tail 50"
   ```

4. **Check memory (common cause on pi-node-c):**

   ```bash
   ssh pi-node-c "free -h; swapon --show; uptime"
   ```

### Common service → port mapping

| Alert instance | Service | Box | Check command |
|----------------|---------|-----|---------------|
| `pi-node-a-metrics:9100` | node_exporter | pi-node-a | `systemctl status prometheus-node-exporter` |
| `pi-node-b-metrics:9100` | node_exporter | pi-node-b | `systemctl status prometheus-node-exporter` |
| `pi-node-c-metrics:9100` | node_exporter | pi-node-c | `systemctl status prometheus-node-exporter` |
| `loki:3100` | Loki | pi-node-c | `systemctl status loki; docker ps \| grep loki` |
| `pi-node-a:8082` | Traefik metrics | pi-node-a | `docker ps \| grep traefik` |
| `pi-node-a:9617` | pihole-exporter | pi-node-a | `docker ps \| grep pihole-exporter` |
| `pi-node-a:8081` | cadvisor | pi-node-a | `docker ps \| grep cadvisor` |

---

## Known architecture notes

- **All services run as Docker containers** managed by NixOS systemd units
  (via `docker compose up -d`), except `node_exporter` and `pihole-FTL` which are
  native NixOS services.
- **pi-node-c has 894 MB RAM and no swap by default** — it was added 2026-03-23
  after Loki OOM'd. Swap is at `/var/swap` (2 GB). Loki is memory-limited to 256 MB.
- **pi-node-c uses pi-node-b as its Nix build host**. If pi-node-b is down or
  its signing key is missing, pi-node-c cannot be rebuilt.
- **Pi-hole**: pi-node-c is the primary DNS / sync source. pi-node-a and pi-node-b
  sync from it twice daily.
- **Loki** lives on pi-node-c at port 3100. Promtail on all boxes pushes to it.
  Grafana on pi-node-b reads from it.
- **Prometheus and Alertmanager** run on pi-node-b. Alerts are emailed via the
  smtp-relay container (Postfix, outbound via Gmail).

---

## Drift prevention

Config for each box lives in `nix-pi-private/modules/<host>.nix`.
If a service is imported but has no `services.X.enable = true` block, it defaults
to disabled and is a dead import — remove it to keep configs accurate.

After any manual change on a box (e.g. `docker restart`, editing a file), follow up
with a proper `nixos-rebuild switch` so the running state matches the declared config.
