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
        rpi-box-01 = mkPi ./hosts/rpi-box-01;
        rpi-box-02 = mkPi ./hosts/rpi-box-02;
        rpi-box-03 = mkPi ./hosts/rpi-box-03;
        # SD image build target (includes sd-image module).
        rpi-box-03-sd = mkPi ./hosts/rpi-box-03/sd-image.nix;
        rpi-box-01-sd = mkPi ./hosts/rpi-box-01/sd-image.nix;
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
