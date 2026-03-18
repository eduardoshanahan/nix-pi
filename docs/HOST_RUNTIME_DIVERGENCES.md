# Host Runtime Divergences

This document is the canonical host-side register for intentional runtime
differences between shared `nix-services` module behavior and the actual
deployed behavior on specific hosts.

Use this file when:

- a host intentionally overrides a generated Compose file or runtime artifact
- a host layers extra runtime policy on top of a shared service module
- a service README in `nix-services` needs to point to the current host reality

Do not duplicate full service module contracts here. Those remain canonical in
`nix-services/services/*/README.md`.

## Ownership Rule

- Shared module behavior/options: `nix-services`
- Host-specific runtime differences: this file in `nix-pi`

## `pi-node-b`

### Homepage

- Shared module: `services.homepageDashboard`
- Intentional divergence:
  - `/etc/homepage/config/docker.yaml` is replaced with a multi-host Docker
    inventory instead of using only the shared module's local Docker-generated
    view.
- Why:
  - the Homepage instance on `pi-node-b` needs to query remote Docker APIs on
    `pi-node-a`, `pi-node-c`, and `nas-host`
- Source of truth:
  - `nixos/hosts/private/pi-node-b.nix`

### Ghost (`blog` instance)

- Shared module: `services.ghost.instances.blog`
- Intentional divergence:
  - `/etc/ghost-blog/docker-compose.yml` is replaced for the `blog` instance
  - adds `mail__options__tls__rejectUnauthorized=false`
- Why:
  - Ghost auth-code mail against the internal SMTP relay has needed TLS
    verification relaxation on this host
- Source of truth:
  - `nixos/hosts/private/pi-node-b.nix`

### Uptime Kuma Monitor Inventory

- Shared module: `services.uptimeKuma`
- Intentional divergence:
  - `pi-node-b` adds:
    - `uptime-kuma-monitor-sync.service`
    - `/etc/uptime-kuma/desired-monitors.json`
    - extra `restartTriggers` on `uptime-kuma-compose.service`
- Why:
  - monitor inventory is treated as host-managed declarative policy rather than
    UI-only state
- Canonical monitor policy:
  - `docs/UPTIME_KUMA_MONITOR_POLICY.md`
- Source of truth:
  - `nixos/hosts/private/pi-node-b.nix`

### Unpoller

- Shared module: `services.unpollerCompose`
- Intentional divergence:
  - `services.unpollerCompose.influxdb.enable = false`
- Why:
  - this host is intentionally Prometheus-only
- Source of truth:
  - `nixos/hosts/private/pi-node-b.nix`

### Postgres Exporter

- Shared module: `services.postgresExporterCompose`
- Intentional divergence:
  - collector toggles:
    - `collectors.wal.enable = false`
    - `collectors.statBgwriter.enable = false`
- Why:
  - match the current Postgres role/version compatibility envelope on this host
- Source of truth:
  - `nixos/hosts/private/pi-node-b.nix`

### MySQL Exporter

- Shared module: `services.mysqlExporterCompose`
- Current state:
  - no intentional compose override remains
  - `pi-node-b` follows the shared module behavior directly
- Why documented:
  - this was previously host-divergent and is now intentionally aligned again

## Update Rule

When a host runtime-affecting override is added, removed, or materially changed:

1. Update this file in the same change.
2. Update the relevant service README in `nix-services` if operators should be
   warned that a host-specific divergence exists.
3. If the change affects Uptime Kuma monitor behavior, also update
   `docs/UPTIME_KUMA_MONITOR_POLICY.md`.
