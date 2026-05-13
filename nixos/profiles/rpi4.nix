{ lib, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";

  hardware.enableAllHardware = lib.mkForce false;

}
