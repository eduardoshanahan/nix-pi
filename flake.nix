{
  description = "nix-pi-2 dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-services.url = "github:eduardoshanahan/nix-services";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ nixpkgs, flake-utils, nixos-hardware, ... }:
    let
      lib = nixpkgs.lib;
      mkBaseSystem = { system, profile, extraModules ? [], hostModule ? null, privateHostModule ? null }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
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
          ]
          ++ (if hostModule != null then [ hostModule ] else [])
          ++ extraModules
          ++ (if privateHostModule != null then [ privateHostModule ] else []);
        };
    in
    {
      nixosConfigurations = {
        # Generic SD images (no hostname baked in).
        rpi4 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
        };
        # Raspberry Pi 3 can run 64-bit (aarch64) and is much faster to build on x86 hosts
        # due to better binary cache coverage than armv7l.
        rpi3 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi3.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-3 ];
        };
        # Optional 32-bit Pi 3 image (slow on x86; may require --impure and NIXPKGS_ALLOW_BROKEN=1).
        rpi3-armv7l = mkBaseSystem {
          system = "armv7l-linux";
          profile = ./nixos/profiles/rpi3-armv7l.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-3 ];
        };

        # Host-specific configs (loaded from gitignored `nixos/hosts/private/` when present).
        rpi-box-01 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateHostModule =
            let p = ./nixos/hosts/private/rpi-box-01.nix;
            in if builtins.pathExists p then p else null;
        };

        rpi-box-02 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateHostModule =
            let p = ./nixos/hosts/private/rpi-box-02.nix;
            in if builtins.pathExists p then p else null;
        };

        rpi-box-03 = mkBaseSystem {
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          privateHostModule =
            let p = ./nixos/hosts/private/rpi-box-03.nix;
            in if builtins.pathExists p then p else null;
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
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
      }
    );
}
