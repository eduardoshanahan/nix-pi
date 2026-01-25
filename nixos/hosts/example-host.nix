{ ... }:
{
  networking.hostName = "example-host";

  # Secrets (sops-nix) example:
  #
  # 1) Put the per-host age private key on the host (not in Git, not in the Nix store),
  #    at /var/lib/sops/age.key
  #
  # 2) Commit only SOPS-encrypted files under `secrets/` (see `.sops.yaml`).
  #
  # 3) Declare secrets and point services at `/run/secrets/...`:
  #
  # lab.sops.ageKeyFile = "/var/lib/sops/age.key";
  # sops.secrets."myservice.env" = {
  #   # Uses `sops.defaultSopsFile` if set, otherwise specify `sopsFile = ./...;`
  #   format = "dotenv";
  #   path = "/run/secrets/myservice.env";
  #   owner = "root";
  #   group = "root";
  #   mode = "0400";
  # };
}
