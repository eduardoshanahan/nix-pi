# Task: deploy nix-services image updates to rpi-box-03

## Status

promoted

## Source Repo

nix-pi

## Context

raspberry-pi

## What was attempted

Applied nix-services image updates (ed0c4ad) to rpi-box-03 via `nixos-rebuild test`
then `switch` with local path overrides (Gitea remote unreachable):

```bash
nixos-rebuild switch \
  --flake path:$PWD#rpi-box-03 \
  --override-input private "path:$PWD/../nix-pi-private" \
  --override-input nix-services "path:$PWD/../../nix-services/nix-services" \
  --target-host eduardo@rpi-box-03 \
  --build-host eduardo@rpi-box-02 \
  --sudo
```

## What worked

- Only loki changed on rpi-box-03: 3.1.1 → 3.7.1 (84.5 MB image)
- Pre-pulled loki image manually before nixos-rebuild (fast, no systemd timeout)
- `nixos-rebuild test` exit code 0
- `nixos-rebuild switch` exit code 0 (clean — no service failures)
- Loki healthy after switch, logging normally

## What failed

Nothing. The rpi-box-03 deploy was clean and uneventful.

## Wrong assumptions

None.

## Reusable insights

- **rpi-box-03 has only one changed service** in a large upstream update — check diff
  before assuming all boxes need the same pre-pull / pre-flight work
- **Pre-pull even small images on RPi**: loki at 84.5 MB still benefits from pre-pull
  to avoid any risk of systemd timeout during extraction on the slow SD card
- **rpi-box-03 uses rpi-box-02 as build host**: confirmed working — `--build-host eduardo@rpi-box-02`

## Candidate for promotion

Nothing new — patterns already captured in rpi-box-02 investigation.
