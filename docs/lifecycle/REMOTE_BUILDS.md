# Remote Builds and Nix Signing

This document defines the operational model for cross-host `nixos-rebuild`
flows where one machine builds and another machine imports the resulting Nix
store paths.

## Current topology

- `pi-node-a`: builds locally
- `pi-node-b`: builds locally and acts as the remote builder for `pi-node-c`
- `pi-node-c`: imports store paths built on `pi-node-b`

Current builder signing identity:

- Builder: `pi-node-b`
- Private key path: `/etc/nix/pi-node-b-priv.pem`
- Public key path: `/etc/nix/pi-node-b-pub.pem`
- Trusted public key string: `pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=`

## Why signing is required

When `nixos-rebuild` uses `--build-host`, any store paths built locally on the
builder are copied from the builder to the target. With `require-sigs = true`,
the target accepts those paths only if they are signed by a trusted key.

Recommended model:

- keep signature checks enabled
- sign locally built paths on the builder
- explicitly trust only the builder keys each target needs

Do not solve this by disabling signature checks on the target.

## Bootstrap the builder signing identity

If a builder is rebuilt from scratch, restore the same signing identity before
using it again as a remote builder. This preserves trust relationships on
targets and avoids unnecessary trust churn.

Helper:

```bash
scripts/bootstrap-nix-signing-key <key-name> <source-host> <target-host> [target-host...]
scripts/bootstrap-nix-signing-key --from-files <private-key-file> <public-key-file> <key-name> <target-host> [target-host...]
```

Examples:

```bash
scripts/bootstrap-nix-signing-key pi-node-b pi-node-b pi-node-c
scripts/bootstrap-nix-signing-key --from-files ./pi-node-b-priv.pem ./pi-node-b-pub.pem pi-node-b pi-node-b
```

Use `--from-files` when the original builder is unavailable and you are
restoring from a secure backup kept outside Git.

## Steady-state rebuild flow

Preflight for `pi-node-c` through `pi-node-b`:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
export NIX_PI_NIX_SERVICES_FLAKE="${NIX_PI_NIX_SERVICES_FLAKE:-$PWD/../nix-services}"

nix run "path:$PWD#validate-private-config" -- pi-node-c
nix run "path:$PWD#validate-pi-host" -- pi-node-c

ssh -o BatchMode=yes -o ConnectTimeout=6 eduardo@pi-node-b \
  "test -f /etc/nix/pi-node-b-priv.pem && test -f /etc/nix/pi-node-b-pub.pem"

ssh -o BatchMode=yes -o ConnectTimeout=6 eduardo@pi-node-c \
  "grep -F 'pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8=' /etc/nix/nix.conf"
```

If any of those checks fail, stop and repair the builder/signing path before
attempting the rebuild.

Example:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nixos-rebuild switch \
  --flake path:$PWD#pi-node-c \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --target-host eduardo@pi-node-c \
  --build-host eduardo@pi-node-b \
  --sudo
```

The declarative requirements are:

- the builder host sets `lab.nix.signingKeyFile`
- the target host includes the builder public key in `lab.nix.trustedPublicKeys`

Recommended post-deploy checks for `pi-node-c`:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 eduardo@pi-node-c \
  "hostname; systemctl is-active traefik pihole loki promtail tailscale"

ssh -o BatchMode=yes -o ConnectTimeout=6 eduardo@pi-node-c \
  "test -f /etc/ssl/certs/homelab-root-ca.crt"
```

If the rebuild succeeds but a post-deploy check fails, treat that as an
incomplete rollout and record the exact failing check in the session handoff.

## If you expand beyond one builder-target pair

For additional remote builder relationships, keep the same model but make it
explicit per builder:

- one signing identity per builder host
- one trusted public key entry per builder on each target that imports from it
- a documented inventory of which targets trust which builders

If remote builds become common across several hosts, consider moving from
ad-hoc `--build-host` usage to a formal distributed build layout:

- define a small set of designated builders
- keep stable builder identities and back them up outside Git
- use Nix build machine configuration (`nix.buildMachines` or equivalent host
  policy) if you want the scheduler to choose builders automatically
- continue treating signer trust as a separate explicit control plane

This keeps capacity planning and trust planning aligned instead of letting trust
sprawl follow incidental SSH reachability.

## Key rotation runbook

Rotate a builder signing key only when necessary (compromise, intentional reset,
or cryptographic hygiene requirement).

1. Generate a new signing keypair on the builder:

```bash
sudo nix-store --generate-binary-cache-key <builder-name> /etc/nix/<builder-name>-priv.pem /etc/nix/<builder-name>-pub.pem
```

1. Read the new public key:

```bash
sudo cat /etc/nix/<builder-name>-pub.pem
```

1. Update the declarative config:

- builder host: ensure `lab.nix.signingKeyFile` points to the active private key
- target hosts: replace the old public key entry in `lab.nix.trustedPublicKeys`

1. Rebuild the builder first so new outputs are signed with the new key.

1. Rebuild each target after it trusts the new public key.

1. Only after all targets are updated, remove the old trusted key from targets
   and securely destroy the retired private key.

Practical note:

- If old outputs still need to be copied during the transition, either keep the
  old key trusted temporarily or rebuild/sign the affected closures before
  removing trust.
