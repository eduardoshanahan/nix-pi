# DNS Migration Execution Log (Zero‑Downtime) — 2026‑01‑28

**Scope:** Phase 3 execution support for `zero_downtime_dns_migration_checklist.md`  
**Goal:** Keep a running record of what we did, what we observed, and how we verified it (commands, UI paths, and rationale).  
**Rule:** Do not paste secrets/tokens/passwords into this log.

---

## Session Metadata

- **Date:** 2026‑01‑28
- **Operator:** Eduardo
- **Assist:** Codex (CLI)
- **Pi‑hole host:** `192.0.2.10`

## Environment Notes (Known So Far)

- Primary LAN interface appears to be `eth0`.
- Host has Docker networking present (`br-*`, `docker0`, `veth*`).

---

## Findings & How We Found Them

### 1) Identify active LAN interface for `192.0.2.10`

**Question:** Which interface is carrying the LAN IP and default route?

**How we checked (command):**

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 eduardo@192.0.2.10 \
  'ip -br link && echo --- && ip -br addr && echo --- && ip route show default'
```

**What we observed (summary):**

- `eth0` is `UP` and has `192.0.2.10/24`.
- Default route is `default via 192.0.2.10 dev eth0`.

**Conclusion:** Use `eth0` as the intended LAN interface for Pi‑hole DNS listening behavior checks.

---

## Execution Log (Chronological)

> Add entries as you go. Prefer short, concrete notes with the exact verification method.

### 2026‑01‑28

- **Action:** Collected baseline network interface info on Pi‑hole host.
  - **Method:** SSH + `ip` summaries and default route.
  - **Result:** LAN interface confirmed as `eth0`.
  - **Notes:** None.

---

## Open Questions / To‑Decide Before Step 1

- Intended upstream DNS servers (IPv4 + optional IPv6).
- Test client choice (device + OS) for Step 3.
- Pi‑hole runtime (systemd service vs Docker/Podman) and where to verify upstream forwarding (UI + logs/packet capture).
