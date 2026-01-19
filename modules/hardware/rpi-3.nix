{
  # Raspberry Pi 3 specific settings live here.
  #
  # Keep this module minimal: most hardware specifics come from each host's
  # `hardware-configuration.nix` once pulled from the device.
  system.nixos.tags = [ "rpi-3" ];
}

