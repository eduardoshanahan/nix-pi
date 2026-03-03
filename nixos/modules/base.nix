{ config, lib, pkgs, ... }:
{
  system.stateVersion = "24.11";

  nix.settings = lib.mkMerge [
    {
      experimental-features = [ "nix-command" "flakes" ];
    }
    (lib.mkIf (config.lab.nix.signingKeyFile != null) {
      secret-key-files = [ config.lab.nix.signingKeyFile ];
    })
    (lib.mkIf (config.lab.nix.trustedPublicKeys != [ ]) {
      trusted-public-keys = lib.mkAfter config.lab.nix.trustedPublicKeys;
    })
  ];

  environment.systemPackages = [
    pkgs.age
    pkgs.sops
  ];

  users.mutableUsers = false;

  services.timesyncd.enable = true;

  security.sudo.wheelNeedsPassword = false;

  # Runtime secrets directory (tmpfs, recreated on every boot)
  systemd.tmpfiles.rules = [
    "d /run/secrets 0700 root root -"
  ];
}
