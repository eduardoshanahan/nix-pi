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
      default = "internal.example";
      description = "Lab domain used for hostnames once DNS is available.";
    };

    privateConfig = {
      source = lib.mkOption {
        type = lib.types.str;
        default = "private-config-template";
        description = "Human-readable description of the active private config source.";
      };

      isPlaceholder = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the active private config is still a placeholder template.";
      };
    };

    sops = {
      ageKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sops/age.key";
        description = "Path to the per-host age private key (must exist on the host; never in the Nix store).";
        example = "/var/lib/sops/age.key";
      };

      defaultSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional default SOPS file path (unencrypted content never enters the Nix store).";
        example = ../nix-pi-private/secrets/secrets.yaml;
      };
    };

    nix = {
      signingKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional local Nix store signing key file for this host.";
        example = "/etc/nix/rpi-box-02-priv.pem";
      };

      trustedPublicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional trusted Nix signing public keys for cross-host store copies.";
        example = [
          "rpi-box-02:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        ];
      };
    };
  };
}
