# Runbook: Pull hardware configuration

Goal: copy the device’s generated `hardware-configuration.nix` into this repo so future deploys are reproducible.

## Run

```bash
./scripts/pull-hardware <host> root@<ip-or-dns>
```

Examples:

```bash
./scripts/pull-hardware rpi-box-01 root@<ip-or-dns>
./scripts/pull-hardware rpi-box-02 root@<ip-or-dns>
./scripts/pull-hardware rpi-box-03 root@<ip-or-dns>
```

## Output

Writes:

- `hosts/<host>/hardware-configuration.nix`

## Verify

- Confirm the file is no longer the empty placeholder.
- Deploy once after pulling to ensure it evaluates cleanly.
