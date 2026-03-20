# Tailscale pi-node-a Recurrence Fix Plan (2026-03-20)

## Context

This note captures the outage investigated on **2026-03-20** from `thinkpad` while offsite (mobile hotspot + Tailscale).

Observed symptom:

- `*.internal.example` resolution from `thinkpad` failed.
- `pi-node-a` appeared offline in Tailscale.

## Confirmed Findings

1. `pi-node-a` host was up on LAN (SSH responded from `hhsnas4` path).
2. `pi-node-a` had no running `tailscale` container at outage time.
3. `tailscale.service` on `pi-node-a` was `active (exited)` because it is a `Type=oneshot` systemd wrapper around Docker Compose.
4. Runtime restart (`sudo systemctl restart tailscale`) recreated the container and restored:
   - Tailscale peer reachability (`tailscale ping pi-node-a` OK)
   - split DNS (`nas-host.internal.example` and `nas2.internal.example` resolved again)

## Root-Cause Hypothesis

The declarative config is present, but lifecycle guarding is insufficient:

- systemd oneshot unit can remain healthy even if container is removed later.
- no automatic reconciliation currently forces recreation when the container disappears outside rebuild/start path.

## Files Most Likely To Edit Next Session

Primary:

- `nix-services/services/tailscale/tailscale.nix`
- `nix-services/services/tailscale/README.md`

Possibly:

- `nix-services/services/tailscale/docker-compose.yml` (only if lifecycle approach needs compose-side tweaks)
- `nix-services/DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md` (if policy/decision updates are made)
- `nix-pi/docs/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md` (add an operator check for this specific failure mode)

## Proposed Fix Directions (Choose One)

### Option A (minimal, low-risk): add container-existence guard + reconcile

In `tailscale.nix`, add an `ExecStartPre` check that:

- verifies Docker daemon is ready
- checks for expected container by name
- if missing, continue to `docker compose up -d` (current behavior already creates it)
- but add explicit post-start verification and fail unit if container is still absent

Pros:

- smallest behavior change
- good immediate safety

Cons:

- still tied to oneshot model

### Option B (stronger): add health/reconcile timer service

Add a small periodic systemd timer on hosts using `tailscaleCompose` that:

- checks container existence and maybe `tailscale status`
- runs `systemctl restart tailscale` if missing/unhealthy

Pros:

- self-healing after manual/accidental container removal

Cons:

- more moving parts
- must avoid flapping/restart loops

### Option C (bigger redesign): move away from oneshot lifecycle for this service

Rework service supervision model to better reflect long-running critical network role.

Pros:

- cleaner lifecycle semantics

Cons:

- highest risk and testing scope

## Recommended Next Session Sequence

1. Reproduce assumptions safely on `pi-node-a` (read-only checks).
2. Implement **Option A** first.
3. Rebuild/deploy `pi-node-a`.
4. Validate:
   - container present after deploy
   - survives reboot
   - survives Docker daemon restart
   - DNS split zone works from `thinkpad` over Tailscale
5. Decide whether Option B is still needed.

## Validation Checklist

On `pi-node-a`:

- `systemctl is-active tailscale`
- `docker ps | grep tailscale`
- `systemctl status tailscale --no-pager -n 80`

From `thinkpad`:

- `tailscale status`
- `tailscale ping pi-node-a`
- `getent hosts nas-host.internal.example`
- `getent hosts nas2.internal.example`

Failure condition to guard against:

- `tailscale.service` reports healthy while container is absent.
