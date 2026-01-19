# Runbook: Pull hardware configuration

Goal: copy the device’s generated `hardware-configuration.nix` into this repo so future deploys are reproducible.

## Run

```bash
./scripts/pull-hardware <host> root@<ip-or-dns>
```

Examples:

```bash
./scripts/pull-hardware pi-node-a root@<ip-or-dns>
./scripts/pull-hardware pi-node-b root@<ip-or-dns>
./scripts/pull-hardware pi-node-c root@<ip-or-dns>
```

## Output

Writes:

- `hosts/<host>/hardware-configuration.nix`

## Verify

- Confirm the file is no longer the empty placeholder.
- Deploy once after pulling to ensure it evaluates cleanly.
