{ ... }:

let
  keysPath = ../../local/authorized-keys.nix;
  keys =
    if builtins.pathExists keysPath then
      import keysPath
    else
      { root = [ ]; pi = [ ]; };
in
{
  imports = [
    ../../modules/common.nix
    ../../modules/networking.nix
    ../../modules/docker.nix
    ../../modules/hardware/rpi-4.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi-box-02";

  users.users.root.openssh.authorizedKeys.keys = keys.root;

  users.users.pi = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = keys.pi;
  };

  system.stateVersion = "24.05";
}
