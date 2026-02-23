{ config, ... }:
{
  networking.useDHCP = true;
  networking.domain = config.lab.domain;
  networking.wireless.enable = false;

  # Keep declarative hostnames (networking.hostName) authoritative.
  # Without this, DHCP can set a transient hostname (for example "nixos").
  networking.dhcpcd.extraConfig = ''
    nohook hostname
  '';
}
