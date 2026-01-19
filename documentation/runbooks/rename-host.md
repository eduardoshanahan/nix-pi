# Runbook: Rename a host

Goal: rename a machine’s Nix flake target and NixOS hostname without losing reproducibility.

## 1) Decide the mapping

- Old hostname / flake target (e.g. `pi-4`)
- New hostname / flake target (e.g. `rpi-box-01`)

## 2) Update this repo

- Rename the host directory under `hosts/`.
- Update `networking.hostName` in the host’s `default.nix`.
- Update `flake.nix` to match the new host name.
- Update any docs (IP examples, commands).

## 3) Deploy to the machine

Deploy using the *new* flake target name, but still pointing at the same IP:

```bash
./scripts/deploy <new-host> root@<ip>
```

## 4) Verify

On the machine:

```bash
hostname
cat /etc/hostname
```

## Notes

- If the machine is already reachable by DNS name, update DNS after the hostname change.
- If `~/.ssh/known_hosts` has an entry for the old name, you may need to remove/refresh it.

