{ config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nix-services.services.traefik
    inputs.nix-services.services.pihole
    inputs.nix-services.services.piholeExporter
    inputs.nix-services.services.cadvisor
    inputs.nix-services.services.promtail
    inputs.nix-services.services.tailscale
  ];

  networking.hostName = "pi-node-a";

  networking.useDHCP = lib.mkForce false;

  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.0.2.10";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.0.2.10";
  # Use internal DNS only so split-horizon zones (for example
  # *.internal.example) always resolve correctly. Keep peer first so this host
  # can still resolve while local Pi-hole restarts.
  networking.nameservers = lib.mkForce [
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

  services.promtailCompose = {
    enable = true;
    lokiPushUrl = "http://192.0.2.10:3100/loki/api/v1/push";
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

  services.cadvisorCompose = {
    enable = true;
    listenAddress = "0.0.0.0";
    listenPort = 8081;
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
  };
}
