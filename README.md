# nix-pi

Provisioning and operating a small Raspberry Pi lab using NixOS flakes.

This repo builds SD card images for:

- Raspberry Pi 4 (aarch64)
- Raspberry Pi 3 (aarch64 by default, armv7l optional)

The public repo stays anonymized; environment-specific values (admin username,
SSH public keys, domains, IPs) live in gitignored private overrides.

## Why This Project

I tried to implement this using Ubuntu, which I have been using for years, and tried to base projects on devcontainers.

The theory was good, but the implementation was a source of frustration. The aim was to have a starting project with Git as a base and add extra tools as needed, but each project started drifting as soon as I started another one, and the attempts to synchronize them were too time consuming.

For this experiment, I decided to try NixOS, which is brand new for me, because I heard [Geoffrey Huntley](https://ghuntley.com/) talking about it.

Also, because it is a brand new thing for me, I used it as a way to learn based on the conversations with Codex.

So far it seems a lot more solid: working in a `nix develop` shell is a lot less problematic than with devcontainers, and after a few days of discontinuous work I managed to have the Raspberry Pis working as expected, with minimal intervention from my part (just flashing cards and powering up).

The next step would be to add some applications, and things might change at that point, but right now I am very happy with the results.

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

cd /home/eduardo/Programming/nix-services
git add .
git commit -m "rebuild"
git push


cd /home/eduardo/Programming/nix-pi
nix flake update nix-services
git add .
git commit -m "rebuild"
git push


cd /home/eduardo/Programming/nix-pi
nixos-rebuild switch \
  --flake path:.#rpi-box-01 \
  --target-host eduardo@rpi-box-01 \
  --build-host eduardo@rpi-box-01 \
  --sudo


cd /home/eduardo/Programming/nix-pi
nixos-rebuild switch \
  --flake path:.#rpi-box-02 \
  --target-host eduardo@rpi-box-02 \
  --build-host eduardo@rpi-box-02 \
  --sudo


cd /home/eduardo/Programming/nix-pi
nixos-rebuild switch \
  --flake path:.#rpi-box-03 \
  --target-host eduardo@rpi-box-03 \
  --build-host eduardo@rpi-box-02 \
  --sudo

ssh-copy-id -i ~/.ssh/meganix_ed25519.pub eduardo@hhnas4.hhlab.home.arpa

```

## Known Good Checks (Loki + Promtail + Node Exporter)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-03 "systemctl is-active loki; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | rg '^loki'; curl -sS -o /dev/null -w '%{http_code}\n' http://192.168.1.10:3100/ready"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-03 "systemctl is-enabled loki-backup.timer; systemctl status loki-backup.timer --no-pager --lines=12"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-01 "systemctl is-active promtail prometheus-node-exporter; curl -sS -o /dev/null -w 'promtail=%{http_code}\n' http://127.0.0.1:9080/ready; curl -sS -o /dev/null -w 'node=%{http_code}\n' http://127.0.0.1:9100/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active promtail prometheus-node-exporter; curl -sS -o /dev/null -w 'promtail=%{http_code}\n' http://127.0.0.1:9080/ready; curl -sS -o /dev/null -w 'node=%{http_code}\n' http://127.0.0.1:9100/metrics"
```

## Known Good Checks (Excalidraw on `rpi-box-02`)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active excalidraw; sudo systemctl --no-pager --lines=40 status excalidraw"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' excalidraw"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -sSI -H 'Host: excalidraw.hhlab.home.arpa' http://127.0.0.1/ | sed -n '1,6p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -skI -H 'Host: excalidraw.hhlab.home.arpa' https://127.0.0.1/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl status excalidraw-healthcheck.timer --no-pager"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "journalctl -u excalidraw-healthcheck -n 50 --no-pager"
```

## Uptime Kuma (`rpi-box-02`)

- URL: `https://kuma.hhlab.home.arpa`
- Initial database selection: `SQLite`
- Persistent data path: `/var/lib/uptime-kuma` (bind-mounted to `/app/data`)

### Baseline monitors configured

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

### Quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active uptime-kuma; sudo systemctl --no-pager --lines=40 status uptime-kuma"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "docker ps --filter name=uptime-kuma --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -skI https://kuma.hhlab.home.arpa/ | sed -n '1,12p'"
```

## Grafana (`rpi-box-02`)

- URL: `https://grafana.hhlab.home.arpa`
- Datasources are provisioned declaratively:
  - `Prometheus` (`http://prometheus:9090`)
  - `Loki` (`http://loki.hhlab.home.arpa:3100`)
- Starter dashboard is provisioned as `Homelab Overview` in folder `Homelab`.

### Quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "systemctl is-active grafana grafana-healthcheck.timer; sudo systemctl --no-pager --lines=40 status grafana grafana-healthcheck.timer"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' grafana"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -sSI -H 'Host: grafana.hhlab.home.arpa' http://127.0.0.1/ | sed -n '1,8p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 "curl -skI https://grafana.hhlab.home.arpa/ | sed -n '1,12p'"
```

### Admin password note

- On first startup with a fresh Grafana data directory, admin password comes from
  `GF_SECURITY_ADMIN_PASSWORD` (generated from `/run/secrets/grafana-admin-password`).
- On an existing Grafana DB, changing the secret does not auto-rotate admin password.
  Reset manually when needed:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 rpi-box-02 'pw="$(sudo docker exec grafana printenv GF_SECURITY_ADMIN_PASSWORD)"; sudo docker exec grafana grafana cli admin reset-admin-password "$pw"'
```

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
