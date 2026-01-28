# Backup Strategy

**Phase:** 2 (Safety Net)

**Purpose:**
Define what must be backed up, what explicitly does **not** need backup, how backups are created, and how restoration is performed.

This document exists to remove ambiguity during failures and before high-risk phases (DNS/DHCP).

---

## Guiding Principles

- Declarative state > mutable state
- If it can be rebuilt deterministically, it does not need backup
- Secrets are backed up **encrypted** or not at all
- Restore procedures matter more than backup tooling

---

## What MUST Be Backed Up

### 1. Git Repositories (Authoritative State)

Repositories:

- `nix-pi`
- `nix-services`

Contents:

- Host configurations
- Service definitions
- Firewall rules
- Documentation (runbooks, checklists)

Backup method:

- Push to remote git (GitHub)
- Optional local mirror on a separate machine

Restore:

- Clone repository
- Follow Reflash & Rejoin Node Runbook

---

### 2. Encrypted Secrets (sops-nix)

Contents:

- Encrypted secret files (`*.yaml`, `*.json`)
- Age/GPG public configuration

Backup method:

- Commit encrypted secrets to git
- Backup age/GPG **private keys** separately (offline)

Restore:

- Restore age/GPG private key
- Clone repo
- Secrets materialize automatically at activation time

---

### 3. Pi-hole Persistent State (Selective)

Contents:

- Gravity database
- Custom blocklists / allowlists
- Local DNS overrides (if used)

Backup method (choose one):

- Export via Pi-hole admin UI
- Periodic copy of Pi-hole data directory (if containerized)

Restore:

- Import settings into fresh Pi-hole
- Verify lists and overrides

Note: This is **convenience state**, not critical state.

---

## What Does NOT Need Backup

- NixOS system state
- `/nix/store`
- Container images
- Runtime secrets under `/run/secrets`
- DHCP leases
- DNS cache

All of the above are either:

- reproducible
- ephemeral
- or actively harmful to restore

---

## Backup Frequency

- Git repositories: on every meaningful change
- Secrets: when rotated or added
- Pi-hole state: before major DNS/DHCP changes

---

## Backup Storage Locations

- Primary: GitHub (private repositories)
- Secondary: optional offline clone (external drive or another node)
- Secrets keys: offline storage only

Never store secret private keys unencrypted in the cloud.

---

## Restore Scenarios

### Scenario A — Single Node Failure

- Reflash node
- Rejoin using runbook
- No backup restore required

### Scenario B — Pi-hole Data Loss

- Reflash node
- Restore Pi-hole state (optional)
- Verify DNS behavior

### Scenario C — Total Cluster Loss

- Restore secrets keys
- Clone repositories
- Reflash nodes one by one
- Rejoin services

---

## Verification & Testing

- [ ] Backup restore procedure tested at least once
- [ ] Secrets decryption tested on a fresh node
- [ ] Pi-hole state restore tested (if backing it up)

---

## Completion Criteria

This strategy is complete when:

- [ ] All required data has a clear backup path
- [ ] Restore steps are documented and tested
- [ ] No critical state exists outside backups

---

**Status:** Draft
**Owner:** Homelab
