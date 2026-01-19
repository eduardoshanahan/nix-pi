{
  description = "NixOS Raspberry Pi fleet (Docker workloads, workstation deployments)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      mkPi =
        hostModule:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ hostModule ];
        };
    in
    {
      nixosConfigurations = {
        pi-node-a = mkPi ./hosts/pi-node-a;
        pi-node-b = mkPi ./hosts/pi-node-b;
        pi-node-c = mkPi ./hosts/pi-node-c;
        # SD image build target (includes sd-image module).
        pi-node-c-sd = mkPi ./hosts/pi-node-c/sd-image.nix;
        pi-node-a-sd = mkPi ./hosts/pi-node-a/sd-image.nix;
      };

      devShells = {
        x86_64-linux.default =
          nixpkgs.legacyPackages.x86_64-linux.mkShell {
            packages = with nixpkgs.legacyPackages.x86_64-linux; [
              git
              openssh
              ripgrep
              ansible
              glibcLocales
            ];
          };

        aarch64-linux.default =
          nixpkgs.legacyPackages.aarch64-linux.mkShell {
            packages = with nixpkgs.legacyPackages.aarch64-linux; [
              git
              openssh
              ripgrep
              ansible
              glibcLocales
            ];
          };
      };


    };
}
