{ config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nix-services.services.traefik
    inputs.nix-services.services.pihole
    inputs.nix-services.services.piholeSync
    inputs.nix-services.services.piholeExporter
    inputs.nix-services.services.dozzleCompose
    inputs.nix-services.services.d2Compose
    inputs.nix-services.services.excalidraw
    inputs.nix-services.services.traggoCompose
    inputs.nix-services.services.cadvisor
    inputs.nix-services.services.promtail
    inputs.nix-services.services.tailscale
    inputs.nix-services.services.dockerSocketProxyCompose
  ];

  networking.hostName = "pi-node-a";
  lab.nix.signingKeyFile = "/etc/nix/pi-node-a-priv.pem";

  networking.useDHCP = lib.mkForce false;

  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.0.2.10";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.0.2.10";
  # Use internal DNS only so split-horizon zones (for example
  # *.internal.example) always resolve correctly. Prefer pi-node-c now that it
  # is the sync source, while keeping the other Pi-hole nodes as fallbacks.
  networking.nameservers = lib.mkForce [
    "192.0.2.10"
    "192.0.2.10"
    "192.0.2.10"
  ];

  # Force sops-nix to use the per-host age key file (lab.sops.ageKeyFile) rather
  # than attempting to decrypt via SSH host keys / GPG.
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];

  sops.secrets.pihole-web-password = {
    sopsFile = ../../../secrets/pihole.yaml;
    format = "yaml";
    key = "pihole-web-password";
    path = "/run/secrets/pihole-web-password";
    owner = "root";
    group = "root";
    mode = "0400";
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

  sops.secrets.tailscale-authkey = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "tailscale-authkey";
    path = "/run/secrets/tailscale-authkey";
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

  sops.secrets.traggo-admin-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "traggo-admin-password";
    path = "/run/secrets/traggo-admin-password";
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

    hostname = "pihole01.${config.lab.domain}";
    timezone = "UTC";

    webPasswordFile = config.sops.secrets.pihole-web-password.path;
    tls = true;
  };

  services.excalidraw = {
    enable = true;
    hostname = "excalidraw.${config.lab.domain}";
    tls = true;
    image = {
      repository = "excalidraw/excalidraw";
      digest = "sha256:3c2513e830bb6e195147c05b34ecf8393d0ba2b1cc86e93b407a5777d6135c6c";
    };
  };

  services.traggoCompose = {
    enable = true;
    hostname = "traggo.${config.lab.domain}";
    tls = true;
    dataDir = "/var/lib/traggo";
    admin = {
      username = "eduardo";
      passwordFile = config.sops.secrets.traggo-admin-password.path;
    };
  };

  services.dozzleCompose = {
    enable = true;
    hostname = "dozzle.${config.lab.domain}";
    tls = true;
    dataDir = "/var/lib/dozzle";
    remoteHosts = [
      "tcp://pi-node-c.${config.lab.domain}:2375|pi-node-c"
      "tcp://nas-host.${config.lab.domain}:2375|nas-host"
    ];
  };

  services.d2Compose = {
    enable = true;
    hostname = "d2.${config.lab.domain}";
    tls = true;
    dataDir = "/var/lib/d2";
    auth.username = "eduardo";
  };

  services.promtailCompose = {
    enable = true;
    lokiPushUrl = "http://loki.${config.lab.domain}:3100/loki/api/v1/push";
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
      host = "pi-node-c";
      user = "eduardo";
    };

    ssh.identityFile = config.sops.secrets.pihole-sync-ssh-key.path;

    schedule = "*-*-* 00,12:00:00";
    randomizedDelaySec = "45m";
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

  services.tailscaleCompose = {
    enable = true;
    hostname = "pi-node-a";
    authKeyFile = config.sops.secrets.tailscale-authkey.path;
    advertiseRoutes = [ "192.0.2.10/24" ];
    acceptRoutes = true;
    acceptDns = false;
    firewallMode = "nftables";
  };

  environment.systemPackages = with pkgs; [
    dnsutils
  ];

  networking.firewall = {
    enable = true;

    allowedTCPPorts = [
      53    # DNS (TCP fallback; Pi-hole)
      80    # Traefik
      443   # Traefik TLS
      8082  # Traefik metrics (Prometheus scrape)
      9080  # promtail metrics (Prometheus scrape)
      9100  # node_exporter (Prometheus scrape)
      9617  # pihole-exporter metrics (Prometheus scrape)
      8081  # cadvisor metrics (Prometheus scrape)
    ];

    allowedUDPPorts = [
      53    # DNS (Pi-hole)
    ];

    # Allow Docker socket proxy only from pi-node-b.
    extraInputRules = ''
      ip saddr 192.0.2.10 tcp dport 2375 accept
    '';
  };
}
