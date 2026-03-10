# n8n Phase 1 Plan (`pi-node-b` + Postgres on `nas-host`)

Status: planned for a future session

## Goal

Deploy n8n on `pi-node-b` as a single-node service with:

- application runtime on `pi-node-b`
- PostgreSQL on `nas-host`
- no Redis in phase 1
- no workers
- low concurrency
- persistent local data on USB-backed storage, but not under `/srv/prometheus`

## Placement decision

- `pi-node-b` is the preferred app host for this phase.
- `nas-host` should provide only the shared PostgreSQL backend for this phase.
- Redis is intentionally deferred unless queue mode is introduced later.

## Storage decision

Do not place n8n data under `/srv/prometheus`.

Reason:

- Repository documentation currently shows `/srv/prometheus` being used by more
  than Prometheus-related data.
- That usage should be audited and corrected separately.
- n8n should start with a cleaner storage boundary.

Preferred candidate paths for the next session:

- `/srv/n8n`
- `/srv/apps/n8n`

Current preference: `/srv/n8n`

## Scope for the implementation session

1. Add a new `n8n` service module in `nix-services`.
1. Follow the existing Docker Compose + systemd module pattern.
1. Use PostgreSQL, not SQLite.
1. Keep deployment single-node only.
1. Route through existing Traefik on `pi-node-b`.
1. Persist the n8n user folder on a dedicated host path outside
   `/srv/prometheus`.
1. Provision a dedicated PostgreSQL role and database on `nas-host`.
1. Wire the database password via the existing runtime secret pattern in
   `nix-pi`.

## Proposed runtime shape

- Host: `pi-node-b`
- Database host: `postgres.internal.example`
- Database port: `5433`
- Database name: `n8n`
- Database user: `n8n`
- Data directory on `pi-node-b`: to be finalized as `/srv/n8n` unless a
  broader `/srv/apps/...` convention is adopted first

## Explicit non-goals for phase 1

- Redis-backed queue mode
- workers
- horizontal scaling
- external binary-data storage
- moving the runtime onto `nas-host`

## Validation checklist for the implementation session

- `systemctl is-active n8n`
- container is healthy/running
- HTTP is reachable through Traefik
- n8n can connect to `postgres.internal.example:5433`
- instance state survives restart
- data is written to the chosen dedicated host path
- no n8n state is placed under `/srv/prometheus`

## Dependencies already verified

- Shared Postgres on `nas-host` is already documented and was confirmed healthy.
- `pi-node-b` is already an application host in this homelab model.

## Follow-up after phase 1

If phase 1 is stable and there is a real need for scaling:

1. evaluate Redis-backed queue mode
1. decide whether `nas-host` should provide Redis for n8n
1. revisit binary-data handling and concurrency limits
