# Private Host Overrides

Place sensitive or environment-specific overrides here. This directory is not
tracked by Git. Create `overrides.nix` to override admin usernames or domains.
For hostnames, add a file that matches the public hostname, for example
`<hostname>.nix`.

Example `overrides.nix`:

```nix
{ ... }:
{
  lab.adminUser = "your-admin";
  # Fully automated SSH access (recommended): embed public keys into the image.
  # This avoids mounting the SD card after flashing.
  lab.adminAuthorizedKeys = [
    "ssh-ed25519 AAAA... comment"
  ];
  lab.domain = "lab.internal.example";
}
```

Example host-specific override `<hostname>.nix`:

```nix
{ ... }:
{
  networking.hostName = "example-host";
}
```

Notes

- This repo is set up so `nixos/hosts/private/` is gitignored; do not commit any
  secrets here.
- When building SD images, use `path:.#...` so Nix can see your local private
  overrides (see `docs/lifecycle/PROVISIONING.md`).
