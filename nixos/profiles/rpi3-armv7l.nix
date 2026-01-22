{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-armv7l-multiplatform.nix"
  ];

  nixpkgs.hostPlatform = "armv7l-linux";

  hardware.enableAllHardware = lib.mkForce false;
}
