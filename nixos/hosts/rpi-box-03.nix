{ pkgs, ... }: {
  # rpi-box-03 is a Raspberry Pi 3. nixos-hardware.raspberry-pi-3 fails to build
  # on the current nixpkgs pin. Use the deprecated linux-rpi kernel directly until
  # this host is retired from the lab.
  boot.kernelPackages = pkgs.linuxPackages_rpi3;
}
