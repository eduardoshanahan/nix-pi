{ config, pkgs, ... }:
{
  networking.useDHCP = true;
  networking.domain = config.lab.domain;
  networking.wireless.enable = false;

  # Keep declarative hostnames (networking.hostName) authoritative.
  # Without this, DHCP can set a transient hostname (for example "nixos").
  networking.dhcpcd.extraConfig = ''
    nohook hostname
  '';

  # Some hosts can retain an old DHCP-provided transient hostname (for example
  # `nixos`) even after the static hostname is configured. Keep the active
  # kernel hostname aligned with `networking.hostName` on every activation.
  system.activationScripts.enforceTransientHostname.text = ''
    if [ -n "${config.networking.hostName}" ]; then
      ${pkgs.systemd}/bin/hostnamectl set-hostname "${config.networking.hostName}" --transient || true
    fi
  '';
}
