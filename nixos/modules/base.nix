{ ... }:
{
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.mutableUsers = false;

  services.timesyncd.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
