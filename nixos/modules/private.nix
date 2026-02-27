{ ... }:
let
  privateOverrides = ../hosts/private/overrides.nix;
in
{
  imports =
    if builtins.pathExists privateOverrides
    then [ privateOverrides ]
    else [];

  # Trust the internal wildcard certificate on all lab hosts so local HTTPS
  # clients can verify services served behind Traefik.
  security.pki.certificateFiles = [
    ../certs/hhlab-wildcard.crt
  ];
}
