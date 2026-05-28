# Known Mistakes — nix-pi (public)

This file contains only public-safe entries. The authoritative list (including
host-specific mistakes with real identifiers) lives in
`../nix-pi-private/.brain/known-mistakes.md`.

Published entries appear here after sanitization via `brainctl publish`.

---

| Date | Mistake | Rule |
| ---- | ------- | ---- |
| 2026-05-10 | `nixos-rebuild switch` does not load the new kernel — a reboot is required | After deploying a nixpkgs update that includes a new kernel, always reboot all boxes. The new NixOS generation activates services in-place but `uname -r` will still show the old kernel until next boot. |
| 2026-05-10 | `docker-socket-proxy` fails after reboot with "network not found" | After a reboot, the container still references a stale Docker network ID. Fix: `sudo docker rm -f docker-socket-proxy && sudo systemctl restart docker-socket-proxy.service`. Check all boxes after every reboot. |
| 2026-05-18 | CMD-SHELL Docker healthcheck fails on distroless images (e.g. grafana/loki 3.x) | Distroless images contain only the app binary — no `/bin/sh`. Use `disable: true` for services monitored externally (Prometheus), or `CMD` with a binary known to be in the image. |
| 2026-05-18 | `nix flake lock --override-input` writes the real hostname into flake.lock | Always sanitize `flake.lock` after updating Gitea-hosted inputs. Replace real hostname with `gitea.internal.example`. Verify with `grep gitea flake.lock` before committing. |
