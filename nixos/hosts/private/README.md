# Private Companion Contract

`nix-pi` no longer treats `nixos/hosts/private/` as the canonical source of
private values.

The real private source of truth is now the sibling flake:

```text
../nix-pi-private
```

This directory is kept only as the tracked public-side contract and migration
reference.

Current public/private split:

- public placeholder input:
  `private-config-template/`
- real private companion:
  `../nix-pi-private`
- override variable used by repo helpers:
  `NIX_PI_PRIVATE_FLAKE`
- optional sibling `nix-services` override for helper validation:
  `NIX_PI_NIX_SERVICES_FLAKE`

Validate the active private config before builds or rebuilds:

```bash
cd /absolute/path/to/nix-pi
nix run "path:$PWD#validate-private-config" -- pi-node-a
nix run "path:$PWD#validate-pi-host" -- pi-node-a
```

For direct `nix build` or `nixos-rebuild` commands, also pass:

```bash
--override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
```
