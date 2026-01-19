{ modulesPath, ... }:

let
  aarch64Module = modulesPath + "/installer/sd-card/sd-image-aarch64.nix";
  # `sd-image-raspberrypi.nix` in nixpkgs 24.05 targets 32-bit Pis (pi0/pi1) and
  # selects the downstream `linux_rpi1` kernel, which is not available on aarch64.
  # For Raspberry Pi 3/4 64-bit images, use the aarch64 SD-image module.
  sdImageModule = aarch64Module;
in
{
  imports = [
    ./default.nix
    sdImageModule
  ];

  # Keep images small + easy to flash.
  sdImage.compressImage = true;
}
