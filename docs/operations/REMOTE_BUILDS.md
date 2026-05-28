# Remote Builds and Nix Signing

This document defines the operational model for cross-host `nixos-rebuild`
flows where one machine builds and another machine imports the resulting Nix
store paths.

## Current topology

- `rpi-box-01`: builds locally
- `rpi-box-02`: builds locally
- `meganix` (x86_64): optional remote builder for any Pi node via binfmt aarch64
  emulation; use with `--build-host meganix.hhlab.home.arpa` for faster builds

Builder signing identities:

| Builder | Private key path                    | Public key trusted by     |
| ------- | ----------------------------------- | ------------------------- |
| meganix | `/etc/nix/meganix-builder-priv.pem` | all Pi nodes (shared.nix) |

Public key strings are managed in nix-pi-private (see `modules/shared.nix` for
the meganix key).

Back up both private key files outside Git so builder identities survive host
rebuilds. Use `scripts/bootstrap-nix-signing-key --from-files` to restore.

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
scripts/bootstrap-nix-signing-key meganix meganix rpi-box-01
scripts/bootstrap-nix-signing-key --from-files ./meganix-priv.pem ./meganix-pub.pem meganix meganix
```

Use `--from-files` when the original builder is unavailable and you are
restoring from a secure backup kept outside Git.

## Building any Pi node via meganix (recommended for speed)

meganix (Threadripper 2920X, 24 threads, 125 GB RAM) has binfmt aarch64
emulation enabled and its signing key trusted by all Pi nodes. Use it as
`--build-host` for significantly faster full-closure rebuilds:

Important:

- If your current shell is already running on `meganix`, do not set
  `--build-host eduardo@meganix.hhlab.home.arpa`.
- In that case the build is already local to `meganix`; setting `--build-host`
  adds an unnecessary SSH hop and can fail due to local hostname/auth setup.
- From local `meganix`, use the "Running from meganix itself" flow below.

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
nixos-rebuild switch \
  --flake path:$PWD#rpi-box-01 \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --target-host eduardo@rpi-box-01 \
  --build-host eduardo@meganix.hhlab.home.arpa \
  --sudo
```

Replace `rpi-box-01` with any Pi node. Meganix pre-flight:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=6 eduardo@meganix.hhlab.home.arpa \
  "test -f /etc/nix/meganix-builder-priv.pem && cat /proc/sys/fs/binfmt_misc/aarch64-linux | grep -q enabled"
```

## Steady-state rebuild flow

Both `rpi-box-01` and `rpi-box-02` build locally. Use meganix as `--build-host`
for significantly faster builds (Threadripper 2920X, 24 threads, 125 GB RAM).

**Running from meganix itself** (most common — repo is on meganix's filesystem):
omit `--build-host`. The local nix-daemon signs with the meganix key:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"

nix run "path:$PWD#validate-private-config" -- rpi-box-01
nix run "path:$PWD#validate-pi-host" -- rpi-box-01

nixos-rebuild switch \
  --flake path:$PWD#rpi-box-01 \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@rpi-box-01 \
  --sudo
```

Replace `rpi-box-01` with `rpi-box-02` as needed.

**Running from a remote machine**: verify meganix is up, then use `--build-host`:

```bash
export NIX_PI_PRIVATE_FLAKE="${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"

ssh -o BatchMode=yes -o ConnectTimeout=6 eduardo@meganix.hhlab.home.arpa \
  "test -f /etc/nix/meganix-builder-priv.pem && \
   cat /proc/sys/fs/binfmt_misc/aarch64-linux | grep -q enabled"

nixos-rebuild switch \
  --flake path:$PWD#rpi-box-01 \
  --override-input private "path:$NIX_PI_PRIVATE_FLAKE" \
  --override-input nix-services "path:$PWD/../nix-services" \
  --target-host eduardo@rpi-box-01 \
  --build-host eduardo@meganix.hhlab.home.arpa \
  --sudo
```

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
