# Uptime Kuma Monitor Policy

This document is the canonical host-side policy note for declarative Uptime
Kuma monitor behavior on `pi-node-b`.

The shared service module in `nix-services` owns container lifecycle for
`services.uptimeKuma`. Host-owned monitor inventory and sync policy live in
`nix-pi`.

## Ownership

- Shared service lifecycle, options, and runtime model:
  - `nix-services/services/uptime-kuma/README.md`
- Host-managed monitor inventory and exceptions:
  - `../nix-pi-private/modules/pi-node-b.nix`
  - this document

## Current Model

`pi-node-b` treats monitor inventory as declarative host policy.

The host adds:

- `uptime-kuma-monitor-sync.service`
- `/etc/uptime-kuma/desired-monitors.json`
- a `restartTriggers` extension on `uptime-kuma-compose.service`

Before Uptime Kuma starts, the host syncs the declarative monitor set into the
SQLite database used by the deployed instance. This ensures newly added
host-managed monitors are already present when Kuma loads its scheduler state.

The current Pi-hole monitor inventory includes:

- `Pi-hole Admin Primary`
- `Pi-hole Admin Secondary`
- `Pi-hole Admin Tertiary`
- `Pi-hole Exporter pi-node-a`
- `Pi-hole Exporter pi-node-b`
- `Pi-hole Exporter pi-node-c`

The inventory also covers shared admin tooling:

- `Adminer` (`https://adminer.<lab-domain>/`, the Synology-hosted MariaDB/MySQL/Postgres UI used by the homelab)

`Pi-hole Admin Tertiary` monitors the additional Pi-hole instance on
`pi-node-c`. `pi-node-c` is now the scheduled `pihole-sync` source for
`pi-node-a` and `pi-node-b`, but the existing primary/secondary operational
labels used for boxes 1 and 2 are intentionally unchanged for now.

## Cluster Observability Phase 1 Coverage

The declarative monitor set now also includes the Phase 1 Raspberry Pi cluster
checks:

- port monitor for `cluster-api.<lab-domain>:6443`
- port monitors for SSH on `cluster-node-01` through `cluster-node-05`
- HTTP monitors for `node_exporter` on
  `cluster-node-01-metrics.<lab-domain>:9100` through
  `cluster-node-05-metrics.<lab-domain>:9100`

The host-managed cluster observability checks now also include:

- HTTPS monitor for `kube-state-metrics.<lab-domain>/metrics`
- HTTPS monitor for `kube-state-metrics.<lab-domain>/apiserver-metrics`

These follow the same default sync behavior as other host-managed port and HTTP
monitors. There are no cluster-specific exceptions in the sync logic at this
time.

## Default Monitor Behavior

For host-managed HTTP monitors, current sync behavior is:

- method: `GET`
- accepted status codes: `200-299`
- `ignore_tls = 1` for `https://...` URLs
- `ignore_tls = 0` for `http://...` URLs
- redirects allowed: `10`

For keyword, DNS, and port monitors, the same sync code in
`../nix-pi-private/modules/pi-node-b.nix` is canonical.

## Current Named Exceptions

### `D2`

- accepted status codes include `401`
- rationale:
  - the service is considered reachable/healthy even when auth blocks the
    request

### `Alertmanager`

- monitor target:
  - `https://alertmanager.<lab-domain>/-/healthy`
- rationale:
  - use the explicit health endpoint instead of relying on the routed root URL

### `Kuma Self`

- monitor target:
  - `https://kuma.<lab-domain>/`
- rationale:
  - monitor the base URL and follow normal redirects instead of depending on
    `/dashboard` being available during the service's own startup window

### `MinIO API`

- monitor target:
  - `https://minio.<lab-domain>/minio/health/live`
- rationale:
  - the MinIO API root commonly returns a non-2xx S3 response for anonymous
    requests
  - the explicit health endpoint gives Kuma a stable `200 OK` signal

### `MinIO Console`

- monitor target:
  - `https://minio-console.<lab-domain>/`
- rationale:
  - the admin console is reverse-proxied on a separate hostname from the S3 API
  - monitoring the console root avoids depending on direct `:9001` access

## Operator Rule

When a host-managed monitor changes because of:

- a service-specific health path
- accepted status-code differences
- TLS verification behavior
- a one-off false-positive pattern

update both:

1. `../nix-pi-private/modules/pi-node-b.nix`
2. this document
