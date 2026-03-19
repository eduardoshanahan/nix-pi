{ config, inputs, lib, ... }:
{
  imports = [
    inputs.nix-services.services.traefik
    inputs.nix-services.services.pihole
    inputs.nix-services.services.piholeSync
    inputs.nix-services.services.piholeExporter
    inputs.nix-services.services.loki
    inputs.nix-services.services.cadvisor
    inputs.nix-services.services.promtail
    inputs.nix-services.services.dockerSocketProxyCompose
  ];

  networking.hostName = "pi-node-c";
  lab.nix.trustedPublicKeys = [
    "pi-node-b:Tn8hXVRqRBvg1734Z/0xcpiRGJocvYC3rqogAGMRQL8="
  ];
  networking.nameservers = lib.mkForce [
    "192.0.2.10"
    "192.0.2.10"
  ];

  fileSystems."/srv" = {
    device = "/dev/disk/by-uuid/7df1b4ce-b6a4-444a-af98-00dbddd96616";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  sops.secrets.traefik-tls-crt = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "traefik-tls-crt";
    path = "/run/secrets/traefik/tls.crt";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.traefik-tls-key = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "traefik-tls-key";
    path = "/run/secrets/traefik/tls.key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.pihole-web-password = {
    sopsFile = ../../../secrets/pihole.yaml;
    format = "yaml";
    key = "pihole-web-password";
    path = "/run/secrets/pihole-web-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.pihole-sync-ssh-key = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "pihole-sync-ssh-key";
    path = "/run/secrets/pihole-sync-ssh-key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.traefik.tls = {
    enable = true;
    certFile = config.sops.secrets.traefik-tls-crt.path;
    keyFile = config.sops.secrets.traefik-tls-key.path;
  };
  services.traefik.httpToHttpsRedirect = true;
  services.traefik.metrics.enable = true;

  services.pihole = {
    enable = true;

    hostname = "pihole03.${config.lab.domain}";
    timezone = "UTC";

    webPasswordFile = config.sops.secrets.pihole-web-password.path;
    tls = true;
  };

  services.piholeExporter = {
    enable = true;
    pihole = {
      hostname = "pihole";
      port = 80;
      protocol = "http";
      passwordFile = config.sops.secrets.pihole-web-password.path;
    };
  };

  services.piholeSync = {
    enable = true;

    source = {
      host = "pi-node-a";
      user = "eduardo";
    };

    ssh.identityFile = config.sops.secrets.pihole-sync-ssh-key.path;

    schedule = "*-*-* 00,12:00:00";
    randomizedDelaySec = "30m";
    stateDir = "/srv/pihole-sync";
    backup.directory = "/srv/backups/pihole-sync";
  };

  services.lokiCompose = {
    enable = true;
    listenAddress = "192.0.2.10";
    dataDir = "/srv/loki/data";
    httpPort = 3100;
    retentionPeriod = "30d";

    backup = {
      enable = true;
      targetDir = "/srv/backups/loki";
      schedule = "daily";
      keepDays = 14;
    };
  };

  services.promtailCompose = {
    enable = true;
    dataDir = "/srv/promtail";
    lokiPushUrl = "http://loki.${config.lab.domain}:3100/loki/api/v1/push";
    syslog = {
      enable = true;
      listenAddress = "0.0.0.0:1514";
      jobLabel = "synology-file-activity";
    };
  };

  services.cadvisorCompose = {
    enable = true;
    listenAddress = "0.0.0.0";
    listenPort = 8081;
  };

  services.dockerSocketProxyCompose = {
    enable = true;
    listenAddress = "192.0.2.10";
    listenPort = 2375;
    socketPath = "/var/run/docker.sock";
    image = {
      tag = "latest";
      allowMutableTag = true;
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" "filesystem" "meminfo" "netdev" "loadavg" "hwmon" ];
  };

  networking.firewall.allowedTCPPorts = [
    53
    80
    443
    1514
    8081
    8082
    9080
    9100
    9617
  ];

  networking.firewall.allowedUDPPorts = [
    53
  ];

  # Allow Docker socket proxy only from pi-node-b.
  networking.firewall.extraInputRules = ''
    ip saddr 192.0.2.10 tcp dport 2375 accept
  '';
}
