# SD Image Artifacts

`nix build` outputs live in `/nix/store` and are exposed via `result-*` symlinks.
If you want a normal file inside this project (for syncing, backups, etc), copy
the built image out of the store:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4
scripts/export-sd-image result-rpi3 sd-image rpi3
```

If you also want the uncompressed `.img` (bigger), add `--decompress`:

```bash
scripts/export-sd-image result-rpi4 sd-image rpi4 --decompress
scripts/export-sd-image result-rpi3 sd-image rpi3 --decompress
```

This writes `sd-image/<name>.img(.zst)` plus a `sha256` file, and these are
gitignored by default.

Provisioning workflow (build/flash/SSH key injection) lives in `docs/PROVISIONING.md`.
