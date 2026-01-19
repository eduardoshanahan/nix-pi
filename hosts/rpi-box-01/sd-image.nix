{ modulesPath, ... }:

let
  sdImageModule = modulesPath + "/installer/sd-card/sd-image-aarch64.nix";
in
{
  imports = [
    ./default.nix
    sdImageModule
  ];

  # Keep images small + easy to flash.
  sdImage.compressImage = true;
}

