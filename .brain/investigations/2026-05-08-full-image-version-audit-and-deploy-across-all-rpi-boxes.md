# Task: full image version audit and deploy across all rpi boxes

## Status

promoted

## Source Repo

nix-pi

## Context

raspberry-pi

## What was attempted

Full image version audit across all ~50 nix-services service modules and all
three RPi host configs (rpi-box-01, rpi-box-02, rpi-box-03). Updated all
outdated pinned tags and deployed to all three boxes.

### How the audit was done

1. Extracted all service default tags from nix-services `*.nix` files with Python
2. Identified hardcoded images in `docker-compose.yml` files (traefik, pihole)
3. Read all three host configs to find host-level overrides
4. Ran parallel registry checks (Docker Hub, ghcr.io via GitHub releases API,
   gcr.io, quay.io, lscr.io/linuxserver via Docker Hub) for all pinned services
5. Verified arm64 availability for all updated images before committing

### Updates made in nix-services (commit 9eb2a41)

- traefik: v3.6.13 → v3.7.0 (hardcoded in docker-compose.yml + render.nix)
- pihole: 2026.04.0 → 2026.04.1 (hardcoded in docker-compose.yml)
- diagrams-net: 29.7.11 → 29.7.12 (options.nix default)
- owntracks-recorder: 1.0.1 → 1.0.1-43 (options.nix default)

### Updates made in nix-pi-private (commits fcc1e00, f161a85)

rpi-box-01:

- dozzle: v10.1.2 → v10.5.2 (host override)
- excalidraw: digest sha256:3c2513e...→sha256:f7ee194... (host override, digest-pinned)

rpi-box-02:

- home-assistant: 2026.4.1 → 2026.5.0 (host override)
- woodpecker server+agent: v2.8.3 → v3.14.0 (host override, major version jump)
- lidarr: 3.0.1.4866-ls10 → 3.1.0.4875-ls27 (linuxserver)
- radarr: 6.0.4.10291-ls295 → 6.1.1.10360-ls301 (linuxserver)
- sonarr: 4.0.16.2944-ls304 → 4.0.17.2952-ls310 (linuxserver)
- prowlarr: 2.3.5.5327-ls142 → 2.3.5.5327-ls145 (linuxserver, same app version)
- lazylibrarian: e7c7ce2d-ls262 → 5f28f033-ls281 (linuxserver rolling release)

### Deploy process

- Pre-pulled all new images on each box before nixos-rebuild (known RPi pattern)
- rpi-box-01 and rpi-box-03 pre-pulls ran in parallel with rpi-box-02 (12 images)
- rpi-box-01 test + switch: exit 0
- rpi-box-02 test + switch: exit 0
- rpi-box-03 test + switch: exit 0
- excalidraw required separate deploy after digest update: exit 0
- No failed units on any box after all deploys

## What worked

- Parallel registry checks via Python ThreadPoolExecutor (20 workers) — fast
- Pre-pulling all images in parallel across boxes before any nixos-rebuild
- Running rpi-box-01 and rpi-box-03 tests in parallel (independent build hosts)
- All services restarted cleanly; no systemd timeout issues (images pre-pulled)

## What failed

Nothing. All deploys clean.

## Wrong assumptions

- Initially assumed rpi-box-01 had no updates because it didn't share the 16
  services from the previous session. It does run traefik and pihole which were
  not part of that batch — they were hardcoded in compose files, not in
  options.nix, so the previous audit missed them.
- grafana 13.1.x tags on Docker Hub all have build suffixes
  (e.g. `13.1.0-25530058790-ubuntu`) — no clean semver tag yet. 13.0.1 is still
  the latest clean release.

## Reusable insights

- **Traefik and pihole tags are hardcoded** in `services/traefik/docker-compose.yml`,
  `services/traefik/render.nix`, and `services/pihole/docker-compose.yml` — not in
  options.nix. They will be missed by any audit that only scans options.nix defaults.
- **Audit pattern for hardcoded images**: `grep -r "image:" services/*/docker-compose.yml`
  catches both hardcoded and env-var-based images; filter for literal version strings.
- **excalidraw digest update workflow**: pull image on box, then
  `docker inspect <image> --format '{{index .RepoDigests 0}}'` gives the digest.
  Image was already pulled so the nixos-rebuild switch was instant.
- **linuxserver rolling releases** (lazylibrarian): tag format is `{commit}-ls{N}`;
  no semver — checking Docker Hub `ordering=last_updated` gives the newest build.
- **woodpecker v2→v3** is a major jump but deployed cleanly with pre-pulled images
  and no postgres/NAS outage to mask issues.
- **owntracks versioning changed**: newer releases use `1.0.1-43` format (with build
  suffix) alongside the plain `1.0.1` tag. Use the suffixed form going forward.

## Candidate for promotion

- Hardcoded traefik/pihole audit pattern → nix-pi known-mistakes.md or constraints.md
- excalidraw digest update workflow → reusable runbook note
