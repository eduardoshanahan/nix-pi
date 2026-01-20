{ ... }:
let
  privateOverrides = ../hosts/private/overrides.nix;
in
{
  imports =
    if builtins.pathExists privateOverrides
    then [ privateOverrides ]
    else [];
}
