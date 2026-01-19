# Working with `nix develop` on Ubuntu

This repo uses Nix flakes and a dev shell so you can work with consistent tooling on an Ubuntu workstation.

## 1) Install Nix (recommended: multi-user daemon)

Install Nix using the official installer (multi-user / daemon mode):

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

Open a new terminal (or source the profile) so `nix` is on your `PATH`.

Verify:

```bash
nix --version
```

## 2) Enable flakes + nix-command

On Ubuntu, the daemon reads `/etc/nix/nix.conf`, and per-user config can live in `~/.config/nix/nix.conf`.

Create the user config:

```bash
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
EOF
```

Verify the features are enabled:

```bash
nix config show | rg 'experimental-features'
```

## 3) Enter the dev shell for this repo

From the repo root:

```bash
nix develop
```

Notes:

- If your machine is `x86_64-linux`, this will enter `devShells.x86_64-linux.default`.
- To start a clean shell without inheriting your environment, use:
  - `nix develop --ignore-environment`

## 4) Common fixes (Ubuntu)

### “cannot connect to socket … nix/daemon-socket/socket”

This means the daemon isn’t running or you don’t have access.

Check:

```bash
systemctl status nix-daemon --no-pager -l
```

Restart (requires sudo):

```bash
sudo systemctl restart nix-daemon
```

### Locale warning: “setlocale: LC_ALL: cannot change locale …”

If your shell sets `LC_ALL`/`LANG` to a locale that isn’t generated on Ubuntu, bash prints warnings.
Either generate the locale on Ubuntu or use a locale that exists (for example `en_US.UTF-8`).
