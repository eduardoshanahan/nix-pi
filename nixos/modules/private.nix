{ ... }:
let
  privateOverrides = ../hosts/private/overrides.nix;
in
{
  imports =
    if builtins.pathExists privateOverrides
    then [ privateOverrides ]
    else [];

  # Trust the internal root CA on all lab hosts so local HTTPS clients can
  # verify services served behind Traefik.
  security.pki.certificateFiles = [
    ../certs/homelab-root-ca.crt
  ];

  # Expose the internal root CA at a stable host path for containers that need
  # to trust lab-internal HTTPS endpoints.
  environment.etc."ssl/certs/homelab-root-ca.crt".source = ../certs/homelab-root-ca.crt;
}
