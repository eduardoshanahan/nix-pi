{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_28;
    daemon.settings = {
      "data-root" = "/srv/docker";
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/docker 0710 root root - -"
  ];

  # Keep Docker from starting against the wrong filesystem during boot.
  # If /srv mounts late (for example after an unclean power cycle), docker
  # must wait or it can bind to rootfs and leave container state inconsistent.
  systemd.services.docker = {
    requires = [ "srv.mount" ];
    after = [ "srv.mount" ];
    unitConfig.RequiresMountsFor = [ "/srv/docker" ];
  };
}
