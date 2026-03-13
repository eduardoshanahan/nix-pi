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

## Housekeeping Reminder

- Added on 2026-03-06.
- Do housekeeping follow-up on 2026-03-10 (or later) after confirming stability:
  - Remove obsolete local sqlite files left from migrations (for example old Grafana/Kuma DB files).
  - Keep current backup snapshots for at least a few more days before deleting any historical copies.
  - Re-check service health and alert noise after the recent database centralization changes.

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
- Remote builds and signing: `docs/REMOTE_BUILDS.md`
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

Deploy (host-local for `pi-node-a` / `pi-node-b`, remote builder for `pi-node-c`)

```bash
cd /home/eduardo/Programming/gitea.internal.example/hhlab-insfrastructure/nix-pi
nix flake update nix-services
git add flake.lock
git commit -m "flake: bump nix-services"
git push

nixos-rebuild switch \
  --flake path:.#pi-node-a \
  --target-host eduardo@pi-node-a \
  --build-host eduardo@pi-node-a \
  --sudo

nixos-rebuild switch \
  --flake path:.#pi-node-b \
  --target-host eduardo@pi-node-b \
  --build-host eduardo@pi-node-b \
  --sudo

nixos-rebuild switch \
  --flake path:.#pi-node-c \
  --target-host eduardo@pi-node-c \
  --build-host eduardo@pi-node-b \
  --sudo

ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub eduardo@<nas-fqdn>
```

Remote build note:

- `pi-node-c` builds on `pi-node-b` because `pi-node-c` does not have enough local build capacity.
- Cross-host Nix store copies require the builder to sign locally built paths and the target to trust the builder public key.
- In the current setup, `pi-node-b` signs with `/etc/nix/pi-node-b-priv.pem`, and `pi-node-c` trusts `pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=`.
- If the builder signing key changes or `pi-node-c` is rebuilt from scratch, re-establish target trust before using `--build-host eduardo@pi-node-b` again.

For bootstrap, expansion, and key rotation details, see `docs/REMOTE_BUILDS.md`.

## `pi-node-b` Storage Policy

- `pi-node-b` has two different storage classes:
  - SD card root filesystem at `/`
  - USB flash storage mounted at `/srv`
- Persistent service state on `pi-node-b` should be placed on the USB-backed `/srv` storage, not on the SD card.
- For new services, prefer dedicated paths such as `/srv/<service>` for application data and `/srv/backups/<service>` for backups.
- Do not place new long-lived application state under `/var/lib/...` on `pi-node-b` unless there is a specific reason it must stay on root.
- Docker on `pi-node-b` is configured to use `/srv/docker` as its data root, so image/layer storage also lives on the USB flash drive.
- Existing service docs in this README that reference `/srv/...` should be treated as following this policy, not as one-off exceptions.

## Monitoring Documentation Boundary

- This README owns host-specific runtime checks and operator quick commands for the currently deployed environment.
- Service-side monitoring architecture, module contracts, and constraints are canonical in `nix-services/monitoring_and_metrics_plan_prometheus_traefik.md` and `nix-services/services/*/README.md`.

## Known Good Checks (Loki + Promtail + Node Exporter)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-c "systemctl is-active loki; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | rg '^loki'; curl -sS -o /dev/null -w '%{http_code}\n' http://<logs-node-lan-ip>:3100/ready"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-c "systemctl is-enabled loki-backup.timer; systemctl status loki-backup.timer --no-pager --lines=12"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-a "systemctl is-active promtail prometheus-node-exporter; curl -sS -o /dev/null -w 'promtail=%{http_code}\n' http://127.0.0.1:9080/ready; curl -sS -o /dev/null -w 'node=%{http_code}\n' http://127.0.0.1:9100/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active promtail prometheus-node-exporter; curl -sS -o /dev/null -w 'promtail=%{http_code}\n' http://127.0.0.1:9080/ready; curl -sS -o /dev/null -w 'node=%{http_code}\n' http://127.0.0.1:9100/metrics"
```

## Known Good Checks (cAdvisor on `pi-node-a` / `pi-node-b` / `pi-node-c`)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-a "systemctl is-active cadvisor; docker ps --filter name=cadvisor --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; curl -sS -o /dev/null -w 'cadvisor=%{http_code}\n' http://127.0.0.1:8081/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active cadvisor; docker ps --filter name=cadvisor --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; curl -sS -o /dev/null -w 'cadvisor=%{http_code}\n' http://127.0.0.1:8081/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-c "systemctl is-active cadvisor; docker ps --filter name=cadvisor --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; curl -sS -o /dev/null -w 'cadvisor=%{http_code}\n' http://127.0.0.1:8081/metrics"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker exec prometheus wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22cadvisor%22%7D'"
```

## Known Good Checks (Excalidraw on `pi-node-b`)

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active excalidraw; sudo systemctl --no-pager --lines=40 status excalidraw"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' excalidraw"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -sSI -H 'Host: <excalidraw-fqdn>' http://127.0.0.1/ | sed -n '1,6p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI -H 'Host: <excalidraw-fqdn>' https://127.0.0.1/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl status excalidraw-healthcheck.timer --no-pager"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "journalctl -u excalidraw-healthcheck -n 50 --no-pager"
```

## D2 Workspace (`pi-node-b`)

- URL: `https://d2.<lab-domain>/`
- Persistent data path: `/srv/d2`
- Generated auth password path (first start, when no external password file is set):
  `/srv/d2/auth/admin-password`

### D2 quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active d2; sudo systemctl --no-pager --lines=40 status d2"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=d2 --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo cat /srv/d2/auth/admin-password"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -sSI -H 'Host: <d2-fqdn>' http://127.0.0.1/ | sed -n '1,8p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://<d2-fqdn>/ | sed -n '1,12p'"
```

## OwnTracks Recorder (`pi-node-b`)

- URL (cleartext, internal-only): `http://owntracks.<lab-domain>:8084/`
- Mobile app publish endpoint: `http://owntracks.<lab-domain>:8084/pub`
- Persistent data path on `pi-node-b`: `/srv/owntracks`
- Storage is on USB-backed `/srv` storage, not the SD card.

### Backup note

- Include `/srv/owntracks` in the same host-level backup flow as the
  other USB-backed application data on `pi-node-b`.
- The important subpaths are:
  - `last/` for current per-device state
  - `rec/` for monthly track history
  - `ghash/` for Recorder metadata

## SMTP Relay (`pi-node-b`)

- Internal relay endpoint: `smtp-relay.<lab-domain>:2525`
- Backing service: `services.smtpRelayCompose` (from `nix-services`)
- Upstream relay: `smtp.gmail.com:587` (authenticated)
- Upstream credential secret: `smtp-relay-upstream-password` -> `/run/secrets/smtp-relay-upstream-password`
- Allowed sender domains are restricted to:
  - `<lab-domain>`
  - `primary.example`
  - `gmail.com`
- Uptime Kuma includes a host-managed `SMTP Relay` monitor on port `2525`.
- Automated backup timer:
  - unit: `smtp-relay-backup.service`
  - schedule: daily (`smtp-relay-backup.timer`)
  - output: `/srv/backups/smtp-relay/<timestamp>/`
- Current status: deployed and verified (`status=sent` in Postfix logs)

### SMTP relay quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active smtp-relay; sudo systemctl --no-pager --lines=40 status smtp-relay"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=smtp-relay --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker logs --tail 80 smtp-relay | grep -E 'status=sent|to=<|from=<' | tail -n 20"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-enabled smtp-relay-backup.timer; systemctl --no-pager --lines=20 status smtp-relay-backup.timer"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo ls -la /srv/backups/smtp-relay | tail -n 20"
```

## Shared Redis (`nas-host`)

- Shared endpoint: `redis.<lab-domain>:6379`
- Runtime owner: `synology-services/nas-host/redis` (not a `nix-pi` host module)
- Current client already using shared Redis: Outline
- Authentication: password-required (`REDIS_URL` with `redis://:<password>@redis.<lab-domain>:6379`)

### Shared Redis quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "cd /volume1/docker/homelab/nas-host/redis && sudo -n /usr/local/bin/docker compose ps"

ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "cd /volume1/docker/homelab/nas-host/redis && sudo -n /usr/local/bin/docker compose logs --tail 60"

ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "cd /volume1/docker/homelab/nas-host/outline && sudo -n /usr/local/bin/docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' outline | grep '^REDIS_URL='"
```

## Dolt (`nas-host`)

- Endpoint: `dolt.internal.example:3307`
- Metrics: `http://dolt.internal.example:11228/metrics`
- Runtime owner: `synology-services/nas-host/dolt` (not a `nix-pi` host module)
- Current visibility:
  - Prometheus job: `dolt`
  - Grafana dashboard: `Shared Infra`
  - Homepage card: `Dolt (shared)`
  - Uptime Kuma monitors: `nas-host Dolt SQL`, `Dolt Metrics`

### Dolt quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "cd /volume1/docker/homelab/nas-host/dolt && sudo -n /usr/local/bin/docker compose ps"

ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "curl -sS http://127.0.0.1:11228/metrics | sed -n '1,20p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker exec prometheus wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22dolt%22%7D'"
```

## Home Assistant (`pi-node-b`)

- URL: `https://homeassistant.<lab-domain>/`
- Service module: `services.homeAssistant` (from `nix-services`)
- Persistent data path: `/srv/home-assistant` (mounted to `/config`)
- Image tag: `ghcr.io/home-assistant/home-assistant:2026.3.0`

### Recorder on Postgres

- Recorder database backend is PostgreSQL (not SQLite) via:
  - `services.homeAssistant.recorder.dbUrlFile = config.sops.secrets.homeassistant-recorder-db-url.path`
- Required SOPS key in `secrets/secrets.yaml`:
  - `homeassistant-recorder-db-url`
  - Value format example:
    - `postgresql://homeassistant:<password>@postgres.<lab-domain>:5433/homeassistant?sslmode=disable`
- Postgres resources (on `nas-host`):
  - Role/user: `homeassistant`
  - Database: `homeassistant`

Migration note:

- Existing SQLite history is not auto-imported.
- Pre-migration SQLite backups are stored on `pi-node-b` under:
  - `/srv/home-assistant/sqlite-backups/`

### Reverse proxy behavior (Traefik)

- Home Assistant is routed through Traefik on the `traefik` Docker network.
- Reverse-proxy trust is configured declaratively via:
  - `services.homeAssistant.reverseProxy.enable = true` (default)
  - `services.homeAssistant.reverseProxy.trustedProxies = [ "172.18.0.0/16" ]`
- The module manages a marked block in `configuration.yaml`:
  - `# BEGIN NIX-SERVICES HOME-ASSISTANT REVERSE PROXY`
  - `# END NIX-SERVICES HOME-ASSISTANT REVERSE PROXY`

### Home Assistant quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active home-assistant; sudo systemctl --no-pager --lines=40 status home-assistant"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=home-assistant --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' home-assistant"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' home-assistant | grep HOME_ASSISTANT_RECORDER_DB_URL"

curl -sk -o /dev/null -w '%{http_code}\n' https://homeassistant.<lab-domain>/

ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "sudo -n /usr/local/bin/docker exec -i nas-host-postgres psql -U postgres -d homeassistant -Atc \"SELECT count(*) FROM information_schema.tables WHERE table_schema='public';\""
```

Expected HTTP behavior:

- `GET /` usually returns `302` (redirect to onboarding/login path).
- `HEAD /` may return `405` (method not allowed), which is normal for this endpoint.

## Uptime Kuma (`pi-node-b`)

- URL: `https://<kuma-fqdn>`
- Current database backend: `MySQL` (`database.type = "mariadb"` in Kuma config)
- Persistent data path: `/var/lib/uptime-kuma` (bind-mounted to `/app/data`)
- Dedicated DB credentials secret: `kuma-db-password` -> `/run/secrets/kuma-db-password`

### Database backend details

- Host: `nas-host.<lab-domain>:3306`
- Database: `uptime_kuma`
- User: `uptime_kuma`
- Kuma uses dedicated service credentials (not MySQL root).

Migration note:

- A pre-migration SQLite backup is stored under:
  - `/var/lib/uptime-kuma/sqlite-backups/`
- After switching from SQLite to MySQL, Kuma starts with a fresh DB unless data
  is migrated separately.

### Baseline UI-managed monitors

These are the monitors currently configured in the Uptime Kuma UI.
They are documented here for operator continuity, but they are not
declaratively provisioned from source code yet.

The desired future monitor set is now generated on `pi-node-b` at:

- `/etc/uptime-kuma/desired-monitors.json`

This file is the declarative source of truth for the host-managed monitors.
On SQLite deployments, `uptime-kuma` syncs and prunes tagged host-managed
monitors in the SQLite database during startup before the container is started.

- `pihole01`
- `Pi-hole Admin`
- `diagrams.net`
- `Excalidraw`
- `Kuma Self`
- `Homepage`
- `n8n`
- `SMTP Relay`
- `Jellyfin`
- `Loki Ready`
- `Node Exporter pi-node-a`
- `Node Exporter pi-node-b`
- `Node Exporter pi-node-c`
- `DNS Pi-hole`

### TLS note for internal services

If Kuma reports certificate verification failures for internal HTTPS monitors,
set `ignoreTls = true` in the Kuma monitor settings (or install internal CA
trust in the container).

### Kuma quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active uptime-kuma-compose; sudo systemctl --no-pager --lines=40 status uptime-kuma-compose"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=uptime-kuma --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://<kuma-fqdn>/ | sed -n '1,12p'"
```

## Grafana (`pi-node-b`)

- URL: `https://<grafana-fqdn>`
- Datasources are provisioned declaratively:
  - `Prometheus` (`http://prometheus:9090`)
  - `Loki` (`http://loki.internal.example:3100`)
- Starter dashboard is provisioned as `Homelab Overview` in folder `Homelab`.
- Application reliability coverage includes `n8n@docker` in both Grafana
  dashboards and Prometheus alert rules.

### Grafana quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active grafana grafana-healthcheck.timer; sudo systemctl --no-pager --lines=40 status grafana grafana-healthcheck.timer"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' grafana"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -sSI -H 'Host: <grafana-fqdn>' http://127.0.0.1/ | sed -n '1,8p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://<grafana-fqdn>/ | sed -n '1,12p'"
```

## Jellyfin (`nas-host`)

- URL: `https://jellyfin.<lab-domain>/`
- Runtime owner: `synology-services/nas-host/jellyfin` (not a `nix-pi` host module)
- Runtime path on NAS: `/volume1/docker/homelab/nas-host/jellyfin`
- Current visibility:
  - Homepage card: `Jellyfin`
  - Uptime Kuma monitor: `Jellyfin`
  - Dozzle: auto-discovered through the existing `nas-host` Docker socket proxy
  - Loki logs: `{job="synology-jellyfin"}`

### Jellyfin quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "cd /volume1/docker/homelab/nas-host/jellyfin && sudo -n /usr/local/bin/docker compose ps"

ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "curl -sS -m 6 -I http://127.0.0.1:8096/ | sed -n '1,8p'"

curl -skI https://jellyfin.<lab-domain>/ | sed -n '1,12p'

ssh -o BatchMode=yes -o ConnectTimeout=6 nas-host "sudo -n /usr/local/bin/docker logs --tail 60 nas-host-jellyfin"
```

## Homepage (`pi-node-b`)

- URL: `https://<homepage-fqdn>`
- Config files are generated declaratively under `/etc/homepage/config`.
- The service mounts the local Docker socket read-only so Homepage can show
  container-backed status for local cards.
- The generated service list includes local `n8n` and `Seerr` cards.

### Homepage quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active homepage; sudo systemctl --no-pager --lines=40 status homepage"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=homepage --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -sSI -H 'Host: <homepage-fqdn>' http://127.0.0.1/ | sed -n '1,8p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://<homepage-fqdn>/ | sed -n '1,12p'"
```

## Seerr (`pi-node-b`)

- URL: `https://seerr.<lab-domain>/`
- Runtime owner: `nix-services/services/seerr`
- Runtime path on host: `/srv/seerr`
- Database backend:
  - Host: `postgres.<lab-domain>:5433`
  - Database: `seerr`
  - User: `seerr`
- Media-server integration:
  - Jellyfin URL: `https://jellyfin.<lab-domain>/`
- Current visibility:
  - Homepage card: `Seerr`
  - Uptime Kuma monitor: `Seerr`
  - Dozzle: local container `seerr`

### Seerr quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active seerr; sudo systemctl --no-pager --lines=40 status seerr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=seerr --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://seerr.<lab-domain>/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker logs --tail 80 seerr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker exec seerr sh -lc 'getent hosts postgres.<lab-domain>; nc -zv postgres.<lab-domain> 5433; getent hosts jellyfin.<lab-domain>'"
```

## Radarr (`pi-node-b`)

- URL: `https://radarr.<lab-domain>/`
- Runtime owner: `nix-services/services/radarr`
- Runtime path on host: `/srv/radarr`
- NAS media mount on host: `/mnt/media` from `nas-host:/volume1/Media`
- Container media mount: `/movies`
- Container downloads mount: `/downloads`
- Database backend:
  - Local SQLite under `/srv/radarr`
  - No shared SQL dependency on `nas-host` in the current first pass
- Media-path status:
  - NAS media export is mounted on `pi-node-b` at `/mnt/media`
  - Use `/movies` inside Radarr for the movie library root
  - Use `/downloads` inside Radarr for completed-download remote path mapping
- Current visibility:
  - Homepage card: `Radarr`
  - Uptime Kuma monitor: `Radarr`
  - Dozzle: local container `radarr`

### Radarr quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active radarr; sudo systemctl --no-pager --lines=40 status radarr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=radarr --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://radarr.<lab-domain>/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker logs --tail 80 radarr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl status mnt-media.automount mnt-media.mount --no-pager"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo ls -la /mnt/media /mnt/media/Movies"
```

## Prowlarr (`pi-node-b`)

- URL: `https://prowlarr.<lab-domain>/`
- Runtime owner: `nix-services/services/prowlarr`
- Runtime path on host: `/srv/prowlarr`
- Database backend:
  - Local SQLite under `/srv/prowlarr`
  - No shared SQL dependency on `nas-host` in the current first pass
- Integration intent:
  - Add indexers once in Prowlarr
  - Sync those indexers into Radarr on `pi-node-b`
- Current visibility:
  - Homepage card: `Prowlarr`
  - Uptime Kuma monitor: `Prowlarr`
  - Dozzle: local container `prowlarr`

### Prowlarr quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active prowlarr; sudo systemctl --no-pager --lines=40 status prowlarr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=prowlarr --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://prowlarr.<lab-domain>/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker logs --tail 80 prowlarr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker exec prowlarr sh -lc 'getent hosts radarr.<lab-domain>; nc -zv radarr.<lab-domain> 443 || nc -zv radarr.<lab-domain> 80'"
```

## Sonarr (`pi-node-b`)

- URL: `https://sonarr.<lab-domain>/`
- Runtime owner: `nix-services/services/sonarr`
- Runtime path on host: `/srv/sonarr`
- NAS media mount on host: `/mnt/media` from `nas-host:/volume1/Media`
- Container media mount: `/media`
- Container downloads mount: `/downloads`
- Database backend:
  - Local SQLite under `/srv/sonarr`
  - No shared SQL dependency on `nas-host` in the current first pass
- Media-path status:
  - NAS media export is mounted on `pi-node-b` at `/mnt/media`
  - Use `/media/TV Shows` inside Sonarr for the TV library root backed by `/mnt/media/TV Shows`
  - Use `/downloads` inside Sonarr for qBittorrent completed-download imports
- Integration intent:
  - qBittorrent downloader endpoint: `http://192.0.2.12:8080`
  - Prowlarr remains the indexer source of truth
  - Seerr should use Sonarr as the series-management backend
- Current visibility:
  - Homepage card: `Sonarr`
  - Uptime Kuma monitor: `Sonarr`
  - Dozzle: local container `sonarr`

### Sonarr quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active sonarr; sudo systemctl --no-pager --lines=40 status sonarr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=sonarr --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI https://sonarr.<lab-domain>/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker logs --tail 80 sonarr"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo ls -la /mnt/media '/mnt/media/TV Shows' /mnt/media/Downloads/qbittorrent"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker exec sonarr sh -lc 'getent hosts prowlarr.<lab-domain> qbittorrent.<lab-domain>; nc -zv 192.0.2.12 8080'"
```

## n8n (`pi-node-b`)

- URL: `https://n8n.<lab-domain>/`
- Runtime owner: `nix-services/services/n8n`
- Runtime path on host: `/srv/n8n`
- Database backend:
  - Host: `postgres.<lab-domain>:5433`
  - Database: `n8n`
  - User: `n8n`
- Current visibility:
  - Homepage card: `n8n`
  - Uptime Kuma monitor: `n8n`
  - Grafana / Prometheus app reliability coverage: `n8n@docker`
  - Dozzle: local container `n8n`

### n8n quick checks

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "systemctl is-active n8n; sudo systemctl --no-pager --lines=40 status n8n"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "docker ps --filter name=n8n --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "curl -skI -H 'Accept: text/html' https://n8n.<lab-domain>/ | sed -n '1,12p'"

ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker logs --tail 60 n8n"
```

### Admin password note

- On first startup with a fresh Grafana data directory, admin password comes from
  `GF_SECURITY_ADMIN_PASSWORD` (generated from `/run/secrets/grafana-admin-password`).
- On an existing Grafana DB, changing the secret does not auto-rotate admin password.
  Reset manually when needed:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b 'pw="$(sudo docker exec grafana printenv GF_SECURITY_ADMIN_PASSWORD)"; sudo docker exec grafana grafana cli admin reset-admin-password "$pw"'
```

## Synology Observability

- NAS hosts: `<nas-a-fqdn>`, `<nas-b-fqdn>`
- NAS-A is scraped via node-exporter under job `synology-nodes`
- NAS-B (older Synology class) is scraped via SNMP (through `snmp-exporter` on `pi-node-b`) under job `synology-snmp`
- The `snmp-exporter` service on `pi-node-b` is also scraped directly under job `snmp-exporter`
- Prometheus scrape targets are configured on `pi-node-b` via:
  - `services.prometheusCompose.scrape.synologyNodeTargets = [ "nas-a.${config.lab.domain}:9100" ];`
  - `services.prometheusCompose.scrape.synologySnmpTargets = [ "nas-b.${config.lab.domain}" ];`
  - `services.prometheusCompose.scrape.synologySnmpExporterAddress = "pi-node-b-metrics.${config.lab.domain}:9116";`

### Prometheus quick check for `snmp-exporter`

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 pi-node-b "sudo docker exec prometheus wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22snmp-exporter%22%7D'"
```

### DSM SNMP settings (required for NAS-B)

In DSM on NAS-B:

- Control Panel -> Terminal & SNMP -> SNMP
- Enable SNMP service
- SNMP version: `v2c`
- Community: `public` (or set a custom value and match `services.prometheusCompose.scrape.synologySnmpAuth`)
- Allow SNMP from your Prometheus/snmp-exporter node IP or network

### DSM file activity -> Loki

- `pi-node-c` promtail listens for DSM syslog on `0.0.0.0:1514`
- DSM Log Center forwarding target:
  - server: `<logs-node-lan-ip>` (or `loki.internal.example`)
  - protocol: `TCP`
  - port: `1514`
- In Grafana Explore (Loki), use:
  - `{job="synology-file-activity"}`
  - `{job="synology-jellyfin"}`

### NAS observability dashboards

Provisioned in Grafana folder `Homelab`:

- `NAS Detail`
- `NAS File Activity`

## Alertmanager Notifications (`pi-node-b`)

- Email notifications are enabled and routed through `smtp-relay.<lab-domain>:2525`.
- Runtime SMTP credential secret: `alertmanager-smtp-password` -> `/run/secrets/alertmanager-smtp-password`.
- Telegram remains disabled by default in current config.
