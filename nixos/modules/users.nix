{ config, lib, ... }:
let
  admin = config.lab.adminUser;
  perNodeUsers = config.lab.perNodeUsers;
  mkUser = name: {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  perNodeAttrs = lib.genAttrs perNodeUsers mkUser;
in
{
  users.users =
    {
      ${admin} = {
        isNormalUser = true;
        extraGroups = [ "wheel" "docker" ];
      };
    }
    // perNodeAttrs;
}
