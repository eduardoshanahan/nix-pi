{ lib, ... }:
{
  options.lab = {
    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Primary admin username on all nodes.";
    };

    adminAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys for the primary admin user (written to /etc/ssh/authorized_keys/<adminUser>).";
      example = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@laptop"
      ];
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
