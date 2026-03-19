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
  - `nixos/hosts/private/pi-node-b.nix`
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

## Cluster Observability Phase 1 Coverage

The declarative monitor set now also includes the Phase 1 Raspberry Pi cluster
checks:

- port monitor for `cluster-api.<lab-domain>:6443`
- port monitors for SSH on `cluster-node-01` through `cluster-node-05`
- HTTP monitors for `node_exporter` on
  `cluster-node-01-metrics.<lab-domain>:9100` through
  `cluster-node-05-metrics.<lab-domain>:9100`

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
`nixos/hosts/private/pi-node-b.nix` is canonical.

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

## Operator Rule

When a host-managed monitor changes because of:

- a service-specific health path
- accepted status-code differences
- TLS verification behavior
- a one-off false-positive pattern

update both:

1. `nixos/hosts/private/pi-node-b.nix`
2. this document
