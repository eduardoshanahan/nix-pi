# Zero‑Downtime DNS Migration Checklist

**Phase:** 3 (FUTURE — planned, not executed yet)

**Purpose:**
Safely migrate DNS resolution from the UCG to Pi‑hole **without downtime**, **without DHCP changes**, and with a **guaranteed rollback path** at every step.

This checklist is written to be followed line‑by‑line during execution.
No step should be skipped or reordered.

---

## Preconditions (MUST ALL BE TRUE)

- [ ] Phase 2 complete and frozen (documentation & safety nets)
- [ ] Pi‑hole container is **healthy** for ≥24h
- [ ] Pi‑hole admin UI reachable through Traefik
- [ ] Secrets injected via `/run/secrets` (no secrets in Nix store)
- [ ] Firewall rules verified (TCP/UDP 53 allowed)
- [ ] UCG remains authoritative for DHCP
- [ ] At least one **non‑critical test client** identified

If any item is false → **STOP**.

---

## Step 0 — Baseline Snapshot (MANDATORY)

Goal: capture the current known-good state before touching DNS.

Actions:

- [ ] Commit current NixOS + service configs to git
- [ ] Tag commit as `pre-dns-migration`
- [ ] Verify `nixos-rebuild switch` is clean (no pending changes)
- [ ] Confirm Pi-hole is **not** used by any client yet
- [ ] Record current DNS servers from UCG
- [ ] Record Pi-hole version, image hash, and container ID

Verification:

- [ ] `git status` clean
- [ ] Pi-hole container/service healthy

Rollback:

- Restore git tag `pre-dns-migration`
- Rebuild system

## Step 1 — Explicit Upstream DNS Configuration

Goal: ensure Pi-hole resolution is deterministic.

Actions:

- [ ] Choose upstream DNS servers intentionally (document choice)
- [ ] Configure explicit upstream DNS servers in Pi-hole
- [ ] Disable any automatic or fallback upstream behavior
- [ ] Restart Pi-hole container/service

Verification:

- [ ] `dig example.com @<pihole-ip>` returns NOERROR
- [ ] Queries forwarded only to intended upstreams

Rollback:

- Restore previous upstream config
- Restart Pi-hole

---

## Step 2 — Non‑Authoritative Resolver Test

Goal: validate Pi‑hole as a resolver **without** production traffic.

Actions:

- [ ] From the Pi host, resolve domains via Pi‑hole
- [ ] From another server, temporarily override `/etc/resolv.conf`

Verification:

- [ ] No SERVFAIL responses
- [ ] Blocklists behave as expected
- [ ] Queries logged correctly in Pi‑hole UI

Rollback:

- Restore original resolver configuration

---

## Step 3 — Single Test Client Migration

Goal: introduce real client traffic with zero blast radius.

Actions:

- [ ] Pick one non‑critical client
- [ ] Manually set its DNS server to Pi‑hole IP
- [ ] Leave DHCP unchanged

Verification (observe for ≥24h):

- [ ] Normal browsing works
- [ ] No intermittent resolution failures
- [ ] No client‑side DNS timeouts
- [ ] Pi‑hole query volume is stable

Rollback:

- Set client DNS back to UCG
- Flush DNS cache on client

---

## Step 4 — Expanded Client Testing (Optional)

Goal: increase confidence before any DHCP work.

Actions:

- [ ] Migrate 1–2 additional non‑critical clients
- [ ] Observe for another 24h

Verification:

- [ ] No degradation under light multi‑client load

Rollback:

- Revert DNS on affected clients only

---

## Step 5 — DNS Migration Hold Point

WARNING: **STOP HERE**

At this point:

- Pi‑hole is proven as a DNS resolver
- UCG is still authoritative
- DHCP has NOT been touched

Do **not** proceed to DHCP migration until:

- Backup strategy document exists
- Reflash & rejoin runbook is tested

---

## Failure Signals (IMMEDIATE ROLLBACK)

Rollback immediately if **any** occur:

- SERVFAIL or NXDOMAIN for known‑good domains
- Random resolution delays
- Client reports of “internet drops”
- Pi‑hole container restarts unexpectedly
- Secrets missing from `/run/secrets`

Rollback = revert client DNS + restart Pi‑hole.

---

## Golden Rules (DNS Phase)

- Never change DNS and DHCP in the same session
- Never migrate more than one variable at once
- If unsure → revert and stop

---

## Phase 2 — Operational Verification (READ-ONLY)

**Purpose:**
Confirm Pi-hole is operationally sound *before* any DNS migration work.
These checks are safe, non-invasive, and do not change network behavior.

Complete all checks before entering Phase 3.

---

### 2.1 Service Health & Stability

Actions:

- [ ] Open Pi-hole Admin UI → *Dashboard*
- [ ] Note "Status", "Uptime", and "Load"
- [ ] On host: check service/container status
  - `systemctl status pihole` **or** `docker ps`
- [ ] Review recent logs for restarts or crashes

Verification:

- [ ] Status shows **healthy / active**
- [ ] Uptime is continuous (no recent resets)
- [ ] No crash-loop or repeated restarts

If failing → stop and investigate stability before proceeding.

---

### 2.2 DNS Query Sanity (One-off)

Actions:

- [ ] From a host on the LAN, run:
  - `dig example.com @<pihole-ip>`
  - `dig google.com @<pihole-ip>`
- [ ] Optionally test AAAA record:
  - `dig ipv6.google.com @<pihole-ip>`

Verification:

- [ ] Response code = **NOERROR**
- [ ] Answers returned quickly (<100–200ms typical)
- [ ] Queries appear immediately in Pi-hole Query Log

Rollback:

- None required (read-only test)

---

### 2.3 Logging & Client Visibility

Actions:

- [ ] Open Pi-hole Admin → *Query Log*
- [ ] Locate the test queries from 2.2

Verification:

- [ ] Queries are logged correctly
- [ ] Client IP matches the querying host
- [ ] Not all queries show `127.0.0.1` or `localhost`

If client IPs are hidden → fix before DNS migration.

---

### 2.4 Listening Interfaces

Actions:

- [ ] Open Pi-hole Admin → *Settings → DNS*
- [ ] Locate "Interface listening behavior"

Verification:

- [ ] Listening on the intended LAN interface(s)
- [ ] Not restricted to localhost only
- [ ] Not listening on unintended external interfaces

Document the chosen mode and why.

---

### 2.5 Firewall Reachability

Actions:

- [ ] From another LAN host, test UDP DNS:
  - `nc -zvu <pihole-ip> 53`
- [ ] Test TCP DNS:
  - `nc -zv <pihole-ip> 53`

Verification:

- [ ] UDP 53 reachable
- [ ] TCP 53 reachable

If blocked → fix firewall rules before proceeding.

---

### Phase 2 Exit Criteria

You may proceed to Phase 3 only if **all** are true:

- [ ] All checks above pass
- [ ] Pi-hole is unused by production clients
- [ ] No unresolved warnings or unexplained behavior
- [ ] Results recorded (notes or git commit)

---

**Status:** Draft
**Owner:** Homelab
**Next document:** Reflash & Rejoin Node Runbook
