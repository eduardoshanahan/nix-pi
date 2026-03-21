{
  description = "Placeholder private config for nix-pi";

  outputs = {
    nixosModules.default = import ./modules/shared.nix;
  };
}
