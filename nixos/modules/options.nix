{ lib, ... }:
{
  options.lab = {
    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Primary admin username on all nodes.";
    };

    perNodeUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional per-node users for delegation.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "lab.home.arpa";
      description = "Lab domain used for hostnames once DNS is available.";
    };
  };
}
