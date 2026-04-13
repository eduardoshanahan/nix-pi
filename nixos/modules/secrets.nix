{ config, lib, ... }:
let
  effectiveDefaultSopsFile =
    if config.lab.sops.defaultSopsFile != null
    then config.lab.sops.defaultSopsFile
    else null;

  effectiveDefaultSopsFileStorePath =
    if effectiveDefaultSopsFile != null
    then builtins.path { path = effectiveDefaultSopsFile; name = "secrets.yaml"; }
    else null;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(lib.hasPrefix "/nix/store/" config.lab.sops.ageKeyFile);
          message = "lab.sops.ageKeyFile must point to a host file, not a Nix store path.";
        }
      ];

      sops = {
        age.keyFile = config.lab.sops.ageKeyFile;
      };
    }

    (lib.mkIf (effectiveDefaultSopsFileStorePath != null) {
      sops.defaultSopsFile = effectiveDefaultSopsFileStorePath;

      # Ensure the encrypted SOPS file is always present on remote build hosts even
      # if some parts of sops-nix coerce the path to a string.
      system.extraDependencies = [ effectiveDefaultSopsFileStorePath ];
    })
  ];
}
