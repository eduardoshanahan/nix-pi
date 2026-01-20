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
      mkHost = { hostname, system, profile, extraModules ? [] }:
        lib.nixosSystem {
          inherit system;
          modules =
          let
            privateHost = ./nixos/hosts/private/${hostname}.nix;
          in
          [
            ./nixos/modules/options.nix
            ./nixos/modules/base.nix
            ./nixos/modules/users.nix
            ./nixos/modules/ssh.nix
            ./nixos/modules/docker.nix
            ./nixos/modules/network.nix
            profile
            ./nixos/hosts/${hostname}.nix
            ./nixos/modules/private.nix
          ]
          ++ extraModules
          ++ (if builtins.pathExists privateHost then [ privateHost ] else []);
        };
    in
    {
      nixosConfigurations = {
        pi-node-01 = mkHost {
          hostname = "pi-node-01";
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
        };
        pi-node-02 = mkHost {
          hostname = "pi-node-02";
          system = "aarch64-linux";
          profile = ./nixos/profiles/rpi4.nix;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
        };
        pi-node-03 = mkHost {
          hostname = "pi-node-03";
          system = "armv7l-linux";
          profile = ./nixos/profiles/rpi3.nix;
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
          ];

          shellHook = ''
            echo "Entering nix-pi-2 dev shell"
          '';
        };
      }
    );
}
