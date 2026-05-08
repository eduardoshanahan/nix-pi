# Task: flake.lock updates and deploys after traefik pihole migration and brain doc promotion

## Status

promoted

## Source Repo

nix-pi

## Context

raspberry-pi

## What was attempted

Follow-on session after the traefik/pihole image migration. Two flake.lock
update + deploy cycles to nix-pi:

**Cycle 1** — picked up nix-services `0c60539`..`390892a` (traefik/pihole
image migration + README updates):

- `nix flake update nix-services --override-input` with real hostname
- Sanitized `gitea.hhlab.home.arpa` → `gitea.internal.example` in flake.lock
- `nixos-rebuild switch` on all three boxes in parallel (exit 0)

**Cycle 2** — picked up nix-services `390892a`..`cb0d513` (brain doc additions:
Nix heredoc escape pattern, pihole options location, README update known-mistake):

- Same update + sanitize workflow
- `nixos-rebuild switch` on all three boxes in parallel (exit 0)

Also in this session:

- Discovered we missed updating service READMEs when adding `image.*` options —
  fixed by adding sections to `services/traefik/README.md` and
  `services/pihole/README.md`
- Promoted three new brain entries (see "Reusable insights" below)

## What worked

- All six nixos-rebuild switch runs: exit 0
- No services restarted on either cycle (doc-only changes produced only a
  manifest update, confirming NixOS correctly detects no activation delta)
- Parallel switch across all three boxes: clean every time

## What failed

Nothing.

## Wrong assumptions

None.

## Reusable insights

- **Doc-only nix-services changes do not trigger service restarts**: when the
  only nix-services change is to `.brain/` docs (AGENT.md, etc.), nixos-rebuild
  switch completes with no stopped/started units — good confirmation that the
  restartTriggers mechanism is scoped correctly to compose/config files.
- **flake.lock hostname sanitization is now documented** in
  `nix-pi-private/.brain/constraints.md` — always check there for the
  `--override-input` command before doing a manual flake update.

## Candidate for promotion

Nothing new beyond what was already promoted to constraints and known-mistakes.
