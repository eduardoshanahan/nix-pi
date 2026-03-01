# nix-pi

Provisioning and operating a small Raspberry Pi lab using NixOS flakes.

This repo builds SD card images for:

- Raspberry Pi 4 (aarch64)
- Raspberry Pi 3 (aarch64 by default, armv7l optional)

The public repo stays anonymized; environment-specific values (admin username,
SSH public keys, domains, IPs) live in gitignored private overrides.

## Public Repo Hygiene

Before commit/push, run the sanitization checklist in:

`PUBLIC_REPO_SANITIZATION_POLICY.md`

## Why This Project

I tried to implement this using Ubuntu, which I have been using for years, and tried to base projects on devcontainers.

The theory was good, but the implementation was a source of frustration. The aim was to have a starting project with Git as a base and add extra tools as needed, but each project started drifting as soon as I started another one, and the attempts to synchronize them were too time consuming.

For this experiment, I decided to try NixOS, which is brand new for me, because I heard [Geoffrey Huntley](https://ghuntley.com/) talking about it.

Also, because it is a brand new thing for me, I used it as a way to learn based on the conversations with Codex.

So far it seems a lot more solid: working in a `nix develop` shell is a lot less problematic than with devcontainers, and after a few days of discontinuous work I managed to have the Raspberry Pis working as expected, with minimal intervention from my part (just flashing cards and powering up).

The next step would be to add some applications, and things might change at that point, but right now I am very happy with the results.

## Documentation Ownership

To avoid duplication and contradictions with `nix-services`, docs are split by responsibility:

- `nix-pi` owns host lifecycle docs: setup, provisioning, flashing, bootstrap, rebuild commands, and SOPS host provisioning.
- `nix-services` owns service lifecycle docs: module options/behavior, Compose + systemd runtime patterns, and service runbooks.

Current-state rule:

- Services are already deployed and stable. Deployment plans should be treated as rebuild/disaster-recovery/expansion references unless a new rollout is explicitly requested.

For the ownership baseline and contradiction register, see:

- `nix-services/documentation_unification_block_1.md`

## Table of Contents

- Getting started: `docs/SETUP.md`
- Provisioning (build, flash, first boot): `docs/PROVISIONING.md`
- Secrets (sops-nix): `docs/SECRETS.md`
- Private overrides (gitignored): `nixos/hosts/private/README.md`
- Local runbook (gitignored): `private/PROVISIONING_LOCAL.md`
- NixOS config layout:
  - Modules: `nixos/modules/`
  - Profiles: `nixos/profiles/`
- Application stacks (planned): `apps/README.md`
- Project records (decisions, work log, session prompt): `records/README.md`

## Quick build commands

Build images (including gitignored private overrides) from the repo root:

```bash
nix build path:.#nixosConfigurations.rpi4.config.system.build.sdImage -o result-rpi4
nix build path:.#nixosConfigurations.rpi3.config.system.build.sdImage -o result-rpi3
```

If you want local image files in this repo (for sync/backups), export them:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4 --decompress
scripts/export-sd-image result-rpi3 sd-image rpi3 --decompress
```

Deploy (building in the target)

```bash

cd /home/eduardo/Programming/private/nix-services
git add .
git commit -m "rebuild"
git push

cd /home/eduardo/Programming/private/nix-pi
nix flake update nix-services
git add .
git commit -m "rebuild"
git push

cd /home/eduardo/Programming/private/nix-pi
nixos-rebuild switch \
  --flake path:.#rpi-box-01 \
  --target-host eduardo@rpi-box-01 \
  --build-host eduardo@rpi-box-01 \
  --sudo

cd /home/eduardo/Programming/private/nix-pi
nixos-rebuild switch \
  --flake path:.#rpi-box-02 \
  --target-host eduardo@rpi-box-02 \
  --build-host eduardo@rpi-box-02 \
  --sudo

cd /home/eduardo/Programming/private/nix-pi
nixos-rebuild switch \
  --flake path:.#rpi-box-03 \
  --target-host eduardo@rpi-box-03 \
  --build-host eduardo@rpi-box-02 \
  --sudo

ssh-copy-id -i ~/.ssh/meganix_ed25519.pub eduardo@<nas-fqdn>

```

## Monitoring Documentation Boundary

- This README owns host-specific runtime checks and operator quick commands for the currently deployed environment.
- Service-side monitoring architecture, module contracts, and constraints are canonical in `nix-services/monitoring_and_metrics_plan_prometheus_traefik.md` and `nix-services/services/*/README.md`.

## Known Good Checks (Loki + Promtail + Node Exporter)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-03 "systemctl is-active loki; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | rg '^loki'; curl -sS -o /dev/null -w '%{http_code}\n' http://<logs-node-lan-ip>:3100/ready"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-03 "systemctl is-enabled loki-backup.timer; systemctl status loki-backup.timer --no-pager --lines=12"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-01 "systemctl is-active promtail prometheus-node-exporter; curl -sS -o /dev/null -w 'promtail=%{http_code}\n' http://127.0.0.1:9080/ready; curl -sS -o /dev/null -w 'node=%{http_code}\n' http://127.0.0.1:9100/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active promtail prometheus-node-exporter; curl -sS -o /dev/null -w 'promtail=%{http_code}\n' http://127.0.0.1:9080/ready; curl -sS -o /dev/null -w 'node=%{http_code}\n' http://127.0.0.1:9100/metrics"
```

## Known Good Checks (cAdvisor on `rpi-box-01` / `rpi-box-02` / `rpi-box-03`)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-01 "systemctl is-active cadvisor; docker ps --filter name=cadvisor --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; curl -sS -o /dev/null -w 'cadvisor=%{http_code}\n' http://127.0.0.1:8081/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active cadvisor; docker ps --filter name=cadvisor --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; curl -sS -o /dev/null -w 'cadvisor=%{http_code}\n' http://127.0.0.1:8081/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-03 "systemctl is-active cadvisor; docker ps --filter name=cadvisor --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; curl -sS -o /dev/null -w 'cadvisor=%{http_code}\n' http://127.0.0.1:8081/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "sudo docker exec prometheus wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22cadvisor%22%7D'"
```

## Known Good Checks (Excalidraw on `rpi-box-02`)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active excalidraw; sudo systemctl --no-pager --lines=40 status excalidraw"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' excalidraw"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -sSI -H 'Host: <excalidraw-fqdn>' http://127.0.0.1/ | sed -n '1,6p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -skI -H 'Host: <excalidraw-fqdn>' https://127.0.0.1/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl status excalidraw-healthcheck.timer --no-pager"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "journalctl -u excalidraw-healthcheck -n 50 --no-pager"
```

## OwnTracks Recorder (`rpi-box-02`)

- URL (cleartext, internal-only): `http://owntracks.<lab-domain>:8084/`
- Mobile app publish endpoint: `http://owntracks.<lab-domain>:8084/pub`
- Persistent data path on `rpi-box-02`: `/srv/prometheus/owntracks`
- Storage is on the USB-backed `/srv/prometheus` filesystem, not the SD card.

### Backup note

- Include `/srv/prometheus/owntracks` in the same host-level backup flow as the
  other USB-backed application data on `rpi-box-02`.
- The important subpaths are:
  - `last/` for current per-device state
  - `rec/` for monthly track history
  - `ghash/` for Recorder metadata

## Uptime Kuma (`rpi-box-02`)

- URL: `https://<kuma-fqdn>`
- Initial database selection: `SQLite`
- Persistent data path: `/var/lib/uptime-kuma` (bind-mounted to `/app/data`)

### Baseline UI-managed monitors

These are the monitors currently configured in the Uptime Kuma UI.
They are documented here for operator continuity, but they are not
declaratively provisioned from source code yet.

The desired future monitor set is now generated on `rpi-box-02` at:

- `/etc/uptime-kuma/desired-monitors.json`

This file is the declarative source of truth for the host-managed monitors.
On existing deployments, `uptime-kuma` now syncs and prunes tagged
host-managed monitors in the SQLite database during startup before the
container is started.

- `pihole01`
- `Pi-hole Admin`
- `diagrams.net`
- `Excalidraw`
- `Kuma Self`
- `Loki Ready`
- `Node Exporter rpi-box-01`
- `Node Exporter rpi-box-02`
- `Node Exporter rpi-box-03`
- `DNS Pi-hole`

### TLS note for internal services

If Kuma reports certificate verification failures for internal HTTPS monitors,
set `ignoreTls = true` in the Kuma monitor settings (or install internal CA
trust in the container).

### Kuma quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active uptime-kuma; sudo systemctl --no-pager --lines=40 status uptime-kuma"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "docker ps --filter name=uptime-kuma --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -skI https://<kuma-fqdn>/ | sed -n '1,12p'"
```

## Grafana (`rpi-box-02`)

- URL: `https://<grafana-fqdn>`
- Datasources are provisioned declaratively:
  - `Prometheus` (`http://prometheus:9090`)
  - `Loki` (`http://loki.internal.example:3100`)
- Starter dashboard is provisioned as `Homelab Overview` in folder `Homelab`.

### Grafana quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active grafana grafana-healthcheck.timer; sudo systemctl --no-pager --lines=40 status grafana grafana-healthcheck.timer"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' grafana"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -sSI -H 'Host: <grafana-fqdn>' http://127.0.0.1/ | sed -n '1,8p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -skI https://<grafana-fqdn>/ | sed -n '1,12p'"
```

### Admin password note

- On first startup with a fresh Grafana data directory, admin password comes from
  `GF_SECURITY_ADMIN_PASSWORD` (generated from `/run/secrets/grafana-admin-password`).
- On an existing Grafana DB, changing the secret does not auto-rotate admin password.
  Reset manually when needed:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 'pw="$(sudo docker exec grafana printenv GF_SECURITY_ADMIN_PASSWORD)"; sudo docker exec grafana grafana cli admin reset-admin-password "$pw"'
```

## Synology Observability

- NAS hosts: `<nas-a-fqdn>`, `<nas-b-fqdn>`
- NAS-A is scraped via node-exporter under job `synology-nodes`
- NAS-B (older Synology class) is scraped via SNMP (through `snmp-exporter` on `rpi-box-02`) under job `synology-snmp`
- The `snmp-exporter` service on `rpi-box-02` is also scraped directly under job `snmp-exporter`
- Prometheus scrape targets are configured on `rpi-box-02` via:
  - `services.prometheusCompose.scrape.synologyNodeTargets = [ "nas-a.${config.lab.domain}:9100" ];`
  - `services.prometheusCompose.scrape.synologySnmpTargets = [ "nas-b.${config.lab.domain}" ];`
  - `services.prometheusCompose.scrape.synologySnmpExporterAddress = "rpi-box-02-metrics.${config.lab.domain}:9116";`

### Prometheus quick check for `snmp-exporter`

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "sudo docker exec prometheus wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22snmp-exporter%22%7D'"
```

### DSM SNMP settings (required for NAS-B)

In DSM on NAS-B:

- Control Panel -> Terminal & SNMP -> SNMP
- Enable SNMP service
- SNMP version: `v2c`
- Community: `public` (or set a custom value and match `services.prometheusCompose.scrape.synologySnmpAuth`)
- Allow SNMP from your Prometheus/snmp-exporter node IP or network

### DSM file activity -> Loki

- `rpi-box-03` promtail listens for DSM syslog on `0.0.0.0:1514`
- DSM Log Center forwarding target:
  - server: `<logs-node-lan-ip>` (or `loki.internal.example`)
  - protocol: `TCP`
  - port: `1514`
- In Grafana Explore (Loki), use:
  - `{job="synology-file-activity"}`

### NAS observability dashboards

Provisioned in Grafana folder `Homelab`:

- `NAS Detail`
- `NAS File Activity`

## Future Reminder: Alertmanager Notifications

Pending task (not enabled yet): configure Alertmanager email + Telegram receivers on `rpi-box-02`.

- Add SOPS entries in `secrets/secrets.yaml`:
  - `alertmanager-smtp-password`
  - `alertmanager-telegram-bot-token`
- Wire them as `sops.secrets` on `rpi-box-02`:
  - `/run/secrets/alertmanager-smtp-password`
  - `/run/secrets/alertmanager-telegram-bot-token`
- In `nixos/hosts/private/rpi-box-02.nix`, set:
  - `services.alertmanager.notifications.email.enable = true;`
  - `services.alertmanager.notifications.telegram.enable = true;`
  - Real values for `from`, `to`, `authUsername`, and `chatId`.
