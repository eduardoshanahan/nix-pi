{
  description = "nix-pi-2 dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, flake-utils, nixos-hardware }:
    let
      lib = nixpkgs.lib;
      mkBaseSystem = { system, profile, extraModules ? [], hostModule ? null, privateHostModule ? null }:
        lib.nixosSystem {
          inherit system;
          modules =
          [
            ./nixos/modules/options.nix
            ./nixos/modules/base.nix
            ./nixos/modules/users.nix
            ./nixos/modules/ssh.nix
            ./nixos/modules/docker.nix
            ./nixos/modules/network.nix
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
            pkgs.zstd
          ];

          shellHook = ''
            echo "Entering nix-pi-2 dev shell"
          '';
        };
      }
    );
}
