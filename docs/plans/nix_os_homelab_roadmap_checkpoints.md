# NixOS Homelab Roadmap & Checkpoints

This document is the **single source of truth** for the homelab migration.
It exists to prevent context loss during long sessions and to provide a clear
restart point at any moment.

---

## Guiding Principles

- One concern at a time
- Declarative over imperative
- No silent state transitions
- Every risky change has a rollback
- No DNS/DHCP big-bang changes

If something feels confusing, **stop and consult this document**.

---

## Current Architecture (Checkpoint 0 — STABLE)

### Hardware

- 3× Raspberry Pi (aarch64-linux)
- Static IPs assigned via NixOS
- UCG Max remains authoritative for **DHCP and DNS**

### Ingress

- Traefik v3.6.7
- Owns ports 80 / 443
- HTTP-only (no TLS yet)

### Pi-hole

- Running in Docker
- Supervised by systemd
- Secrets injected at runtime via sops-nix → /run/secrets
- UI reachable at: <http://pihole.local/admin/>
- Healthcheck: **healthy**

### Firewall

- Enabled via NixOS
- Allowed:
  - TCP: 80, 443, 53
  - UDP: 53

Baseline: this is the **known-good baseline**.
Do not modify multiple axes at once.

---

## Phase 1 — Service Foundations (DONE)

- [x] Traefik deployed (HTTP-only)
- [x] Pi-hole deployed behind Traefik
- [x] Runtime secret injection pattern validated
- [x] Firewall enabled and verified
- [x] Rollback tested

---

## Phase 2 — Documentation & Safety Nets (CURRENT)

### Goals

- Freeze current state
- Eliminate ambiguity
- Make failures reversible

### Tasks

- [x] Runtime secrets helper extracted
- [x] Pi-hole deployment documented
- [x] Zero-downtime DNS migration checklist
- [x] Reflash & rejoin node runbook
- [x] Backup strategy document

Warning: no functional changes to the network in this phase.

---

## Phase 3 — DNS Migration (FUTURE)

### Strategy

- Gradual
- Reversible
- One client at a time

### Planned Steps (DNS)

1. Add upstream DNS explicitly in Pi-hole
2. Test Pi-hole as *non-authoritative* resolver
3. Switch **one test client** to Pi-hole DNS
4. Observe for 24h
5. Roll back if needed

Do not make DHCP changes yet.

---

## Phase 4 — DHCP Migration (FUTURE)

### Preconditions (DHCP)

- DNS stable on Pi-hole
- Backups in place
- Reflash runbook tested

### Planned Steps (DHCP)

1. Mirror UCG DHCP settings in Pi-hole
2. Disable DHCP on UCG **temporarily**
3. Enable DHCP on Pi-hole
4. Validate lease assignment
5. Reboot one non-critical client

---

## Phase 5 — TLS Enablement (FUTURE)

### Preconditions (TLS)

- Pi-hole authoritative DNS
- Hostnames resolving correctly

### Planned Steps (TLS)

1. Enable TLS entrypoints in Traefik
2. Configure certificate resolver
3. Enable HTTPS router for Pi-hole
4. Verify UI access over HTTPS
5. Remove HTTP access if desired

---

## How to Use This Document

- At the start of a session: identify the **current phase**
- During work: only touch items in that phase
- If something breaks: roll back to last checkpoint
- If ChatGPT context drifts: paste the relevant section back

---

## Golden Rule

> If you cannot explain *why* a step exists,
> it does not get executed.

---

**Last confirmed checkpoint:** Phase 2 — Documentation & Safety Nets
