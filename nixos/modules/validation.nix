{ config, ... }:
{
  assertions = [
    {
      assertion = !config.lab.privateConfig.isPlaceholder;
      message = ''
        The active private config is still the public placeholder template.
        Create a sibling nix-pi-private flake and point validation/build
        commands at it with NIX_PI_PRIVATE_FLAKE if needed.
      '';
    }
    {
      assertion = config.lab.adminAuthorizedKeys != [ ];
      message = "Set lab.adminAuthorizedKeys in the private flake before building images or rebuilding hosts.";
    }
  ];
}
