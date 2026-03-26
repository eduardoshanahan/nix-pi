{
  description = "nix-pi-2 dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-services.url = "git+ssh://git@gitea.internal.example:2222/eduardo/nix-services.git?ref=main";
    sops-nix.url = "github:Mic92/sops-nix";
    private.url = "path:./private-config-template";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, nixos-hardware, private, ... }:
    let
      lib = nixpkgs.lib;
      privateModuleOrNull = name: lib.attrByPath [ "nixosModules" name ] null private;

      mkBaseSystem = { system, profile, extraModules ? [], hostModule ? null, privateSharedModule ? null, privateHostModule ? null }:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs self;
            piRepoRoot = ./.;
            privateRepoRoot = inputs.private.outPath;
          };
          modules =
          [
            ./nixos/modules/options.nix
            ./nixos/modules/base.nix
            ./nixos/modules/users.nix
            ./nixos/modules/ssh.nix
            ./nixos/modules/docker.nix
            ./nixos/modules/network.nix
            inputs.sops-nix.nixosModules.sops
            ./nixos/modules/secrets.nix
            profile
            ./nixos/modules/private.nix
            ./nixos/modules/validation.nix
          ]
          ++ (if hostModule != null then [ hostModule ] else [])
          ++ extraModules
          ++ (if privateSharedModule != null then [ privateSharedModule ] else [])
          ++ (if privateHostModule != null then [ privateHostModule ] else []);
        };

      privateSharedOverrides = privateModuleOrNull "default";
      maybePrivateHost = name: privateModuleOrNull name;
    in
    {
      nixosConfigurations = {
        # Generic SD images (no hostname baked in).
        rpi4 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateSharedModule = privateSharedOverrides;
        };
        # Raspberry Pi 3 can run 64-bit (aarch64) and is much faster to build on x86 hosts
        # due to better binary cache coverage than armv7l.
        rpi3 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi3.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-3 ];
          privateSharedModule = privateSharedOverrides;
        };
        # Optional 32-bit Pi 3 image (slow on x86; may require --impure and NIXPKGS_ALLOW_BROKEN=1).
        rpi3-armv7l = mkBaseSystem {
          system = "armv7l-linux";
          profile = ./nixos/profiles/rpi3-armv7l.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-3 ];
          privateSharedModule = privateSharedOverrides;
        };

        # Host-specific configs with private companion modules layered on top.
        pi-node-a = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          hostModule = ./nixos/hosts/pi-node-a.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "pi-node-a";
        };

        pi-node-b = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          hostModule = ./nixos/hosts/pi-node-b.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "pi-node-b";
        };

        pi-node-c = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          hostModule = ./nixos/hosts/pi-node-c.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "pi-node-c";
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        validatePrivateConfig = pkgs.writeShellApplication {
          name = "validate-private-config";
          runtimeInputs = [
            pkgs.jq
            pkgs.nix
          ];
          text = ''
            set -euo pipefail

            quiet=0

            usage() {
              cat >&2 <<'EOF'
            usage: validate-private-config [--quiet] [nixosConfiguration]

              --quiet  Only print failures.

            Validates that a real private flake exists and that path-based
            evaluation resolves the required private values.
            EOF
              exit 1
            }

            while [ "$#" -gt 0 ]; do
              case "$1" in
                --quiet)
                  quiet=1
                  shift
                  ;;
                --help|-h)
                  usage
                  ;;
                --*)
                  echo "unknown option: $1" >&2
                  usage
                  ;;
                *)
                  break
                  ;;
              esac
            done

            if [ "$#" -gt 1 ]; then
              usage
            fi

            node="''${1:-pi-node-a}"
            repo_flake_path="path:${self}"
            flake_ref="$repo_flake_path#nixosConfigurations.$node"
            private_flake_dir="''${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"

            if [ ! -f "$private_flake_dir/flake.nix" ]; then
              cat >&2 <<EOF
            missing private flake: $private_flake_dir/flake.nix

            Create a sibling nix-pi-private flake there, or point
            NIX_PI_PRIVATE_FLAKE at the real private flake location.

            The tracked template lives at:
              nix-pi/private-config-template
            EOF
              exit 1
            fi

            override_args=(--no-write-lock-file)
            if [ -n "''${NIX_PI_NIX_SERVICES_FLAKE:-}" ]; then
              override_args+=(--override-input nix-services "path:$NIX_PI_NIX_SERVICES_FLAKE")
            fi
            override_args+=(--override-input private "path:$private_flake_dir")

            private_source="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.privateConfig.source" --raw)"
            private_placeholder="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.privateConfig.isPlaceholder" --json)"

            if [ "$private_placeholder" = "true" ]; then
              echo "private config check failed: private flake source '$private_source' is still the placeholder template" >&2
              exit 1
            fi

            admin_user="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.adminUser" --raw)"
            domain="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.domain" --raw)"
            admin_keys_json="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.adminAuthorizedKeys" --json)"

            if ! printf '%s' "$admin_keys_json" | jq -e 'length > 0' >/dev/null; then
              echo "private config check failed: lab.adminAuthorizedKeys is empty for $node" >&2
              exit 1
            fi

            if [ "$quiet" -eq 0 ]; then
              echo "private config OK for $node"
              echo "private_source=$private_source"
              echo "admin_user=$admin_user"
              echo "domain=$domain"
              echo "admin_keys=$(printf '%s' "$admin_keys_json" | jq 'length')"
            fi
          '';
        };
        validatePiHost = pkgs.writeShellApplication {
          name = "validate-pi-host";
          runtimeInputs = [ validatePrivateConfig pkgs.nix ];
          text = ''
            set -euo pipefail

            if [ "$#" -ne 1 ]; then
              echo "usage: validate-pi-host <nixosConfiguration>" >&2
              exit 1
            fi

            node="$1"
            validate-private-config --quiet "$node"
            repo_flake_path="path:${self}"
            private_flake_dir="''${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"
            override_args=(--no-write-lock-file)
            if [ -n "''${NIX_PI_NIX_SERVICES_FLAKE:-}" ]; then
              override_args+=(--override-input nix-services "path:$NIX_PI_NIX_SERVICES_FLAKE")
            fi
            override_args+=(--override-input private "path:$private_flake_dir")
            flake_ref="$repo_flake_path#nixosConfigurations.$node"

            hostname="$(nix eval "''${override_args[@]}" "$flake_ref.config.networking.hostName" --raw)"
            toplevel_drv="$(nix eval "''${override_args[@]}" "$flake_ref.config.system.build.toplevel.drvPath" --raw)"

            echo "hostname=$hostname"
            echo "toplevel_drv=$toplevel_drv"
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.prek
            pkgs.gitleaks
            pkgs.nodePackages.markdownlint-cli2
            pkgs.sops
            pkgs.age
            pkgs.zstd
            pkgs.nixos-rebuild
            pkgs.deadnix
          ];

          shellHook = ''
            echo "Entering nix-pi-2 dev shell"

            # Auto-install (and optionally run) prek hooks when entering the dev shell.
            # Opt out with `SKIP_PREK=1 nix develop`.
            if [ -z "''${SKIP_PREK:-}" ] && [ -d .git ] && [ -f .pre-commit-config.yaml ] && command -v prek >/dev/null 2>&1; then
              if [ -z "''${NIX_PI2_PREK_DONE:-}" ]; then
                export NIX_PI2_PREK_DONE=1

                echo "prek: installing git hooks"
                prek install --install-hooks 2>/dev/null || prek install || true

                # Run once on entry; disable with SKIP_PREK_RUN=1.
                if [ -z "''${SKIP_PREK_RUN:-}" ]; then
                  echo "prek: running hooks (all files)"
                  prek run --all-files || true
                fi
              fi
            fi
          '';
        };

        packages.validate-private-config = validatePrivateConfig;
        packages.validate-pi-host = validatePiHost;

        apps.validate-private-config = {
          type = "app";
          program = "${validatePrivateConfig}/bin/validate-private-config";
        };

        apps.validate-pi-host = {
          type = "app";
          program = "${validatePiHost}/bin/validate-pi-host";
        };
      }
    );
}
