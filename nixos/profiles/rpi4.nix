{ lib, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";

  hardware.enableAllHardware = lib.mkForce false;

  # Direct kernel console output to HDMI (tty1) so a connected monitor
  # shows boot messages and a getty login prompt.
  boot.kernelParams = [ "console=tty1" ];
}
