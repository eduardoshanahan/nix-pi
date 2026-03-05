{ config, inputs, lib, pkgs, ... }:
let
  githubProfileExporter = pkgs.writeText "github-profile-exporter.py" ''
    #!/usr/bin/env python3
    import json
    import os
    import time
    import datetime
    import urllib.error
    import urllib.parse
    import urllib.request
    from http.server import BaseHTTPRequestHandler, HTTPServer

    USERNAME = os.environ.get("GITHUB_PROFILE_USERNAME", "eduardoshanahan")
    PORT = int(os.environ.get("GITHUB_PROFILE_EXPORTER_PORT", "9145"))
    CACHE_TTL_SECONDS = int(os.environ.get("GITHUB_PROFILE_CACHE_TTL_SECONDS", "3600"))

    state = {
      "last_fetch": 0.0,
      "up": 0,
      "error": "",
      "metrics": {},
    }

    def fetch_json(url):
      req = urllib.request.Request(
        url,
        headers={
          "User-Agent": "homelab-github-profile-exporter",
          "Accept": "application/vnd.github+json",
        },
      )
      with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))

    def fetch_json_with_status(url):
      req = urllib.request.Request(
        url,
        headers={
          "User-Agent": "homelab-github-profile-exporter",
          "Accept": "application/vnd.github+json",
        },
      )
      try:
        with urllib.request.urlopen(req, timeout=10) as resp:
          return resp.status, json.loads(resp.read().decode("utf-8"))
      except urllib.error.HTTPError as err:
        try:
          body = err.read().decode("utf-8")
          parsed = json.loads(body) if body else None
        except Exception:
          parsed = None
        return err.code, parsed

    def fetch_commit_count_days(days):
      since_date = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)).date().isoformat()
      query = f"author:{USERNAME} author-date:>={since_date}"
      url = f"https://api.github.com/search/commits?q={urllib.parse.quote_plus(query)}&per_page=1"
      payload = fetch_json(url)
      return int(payload.get("total_count", 0))

    def fetch_metrics():
      user = fetch_json(f"https://api.github.com/users/{urllib.parse.quote(USERNAME)}")

      repos = []
      page = 1
      while True:
        page_data = fetch_json(
          f"https://api.github.com/users/{urllib.parse.quote(USERNAME)}/repos?per_page=100&page={page}"
        )
        if not page_data:
          break
        repos.extend(page_data)
        if len(page_data) < 100:
          break
        page += 1
        if page > 20:
          break

      total_stars = sum(int(repo.get("stargazers_count", 0)) for repo in repos)
      total_forks = sum(int(repo.get("forks_count", 0)) for repo in repos)
      total_watchers = sum(int(repo.get("watchers_count", 0)) for repo in repos)
      total_open_issues = sum(int(repo.get("open_issues_count", 0)) for repo in repos)
      commit_counts = {
        "1d": fetch_commit_count_days(1),
        "7d": fetch_commit_count_days(7),
        "30d": fetch_commit_count_days(30),
        "365d": fetch_commit_count_days(365),
      }
      repos_ready = 0
      repos_pending = 0

      for repo in repos:
        repo_name = repo.get("name")
        owner = (repo.get("owner") or {}).get("login", USERNAME)
        if not repo_name:
          continue
        endpoint = (
          f"https://api.github.com/repos/{urllib.parse.quote(owner)}/"
          f"{urllib.parse.quote(repo_name)}/stats/contributors"
        )
        status, contributors = fetch_json_with_status(endpoint)
        if status == 202:
          repos_pending += 1
          continue
        if status >= 400 or not isinstance(contributors, list):
          repos_pending += 1
          continue

        repos_ready += 1
        selected = None
        for contributor in contributors:
          author = (contributor.get("author") or {}).get("login", "")
          if author.lower() == USERNAME.lower():
            selected = contributor
            break
        if selected is None:
          continue

        # Keep diagnostics from contributor stats endpoint to track GitHub backend readiness.
        _ = selected

      return {
        "github_profile_followers": int(user.get("followers", 0)),
        "github_profile_following": int(user.get("following", 0)),
        "github_profile_public_repos": int(user.get("public_repos", 0)),
        "github_profile_public_gists": int(user.get("public_gists", 0)),
        "github_profile_total_stars": total_stars,
        "github_profile_total_forks": total_forks,
        "github_profile_total_watchers": total_watchers,
        "github_profile_total_open_issues": total_open_issues,
        "github_profile_commits_1d": commit_counts["1d"],
        "github_profile_commits_7d": commit_counts["7d"],
        "github_profile_commits_30d": commit_counts["30d"],
        "github_profile_commits_365d": commit_counts["365d"],
        "github_profile_commit_repos_ready": repos_ready,
        "github_profile_commit_repos_pending": repos_pending,
      }

    def refresh_if_needed():
      now = time.time()
      if now - state["last_fetch"] < CACHE_TTL_SECONDS and state["metrics"]:
        return
      try:
        state["metrics"] = fetch_metrics()
        state["up"] = 1
        state["error"] = ""
        state["last_fetch"] = now
      except Exception as exc:
        state["up"] = 0
        state["error"] = str(exc).replace("\n", " ")
        state["last_fetch"] = now

    def prometheus_text():
      refresh_if_needed()
      lines = []
      lines.append("# HELP github_profile_up Exporter scrape/update status (1=ok, 0=error)")
      lines.append("# TYPE github_profile_up gauge")
      lines.append(f'github_profile_up{{username="{USERNAME}"}} {state["up"]}')
      lines.append("# HELP github_profile_last_fetch_unixtime Last GitHub API fetch time")
      lines.append("# TYPE github_profile_last_fetch_unixtime gauge")
      lines.append(f'github_profile_last_fetch_unixtime{{username="{USERNAME}"}} {int(state["last_fetch"])}')
      for metric, value in state["metrics"].items():
        lines.append(f"# TYPE {metric} gauge")
        lines.append(f'{metric}{{username="{USERNAME}"}} {value}')
      if state["error"]:
        escaped = state["error"].replace("\\\\", "\\\\\\\\").replace('"', '\\"')
        lines.append("# HELP github_profile_error_info Last exporter error")
        lines.append("# TYPE github_profile_error_info gauge")
        lines.append(f'github_profile_error_info{{username="{USERNAME}",error="{escaped}"}} 1')
      return "\n".join(lines) + "\n"

    class Handler(BaseHTTPRequestHandler):
      def do_GET(self):
        if self.path not in ["/metrics", "/"]:
          self.send_response(404)
          self.end_headers()
          return
        body = prometheus_text().encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

      def log_message(self, fmt, *args):
        return

    if __name__ == "__main__":
      server = HTTPServer(("0.0.0.0", PORT), Handler)
      server.serve_forever()
  '';
  mkHttpMonitor = name: url: {
    inherit name url;
    kind = "http";
  };
  mkKeywordMonitor = name: url: keyword: {
    inherit name url keyword;
    kind = "keyword";
  };
  mkDnsMonitor = name: hostname: dnsResolveServer: {
    inherit name hostname dnsResolveServer;
    kind = "dns";
  };
  mkNamedHttpMonitors = names: urls:
    lib.zipListsWith (name: url: mkHttpMonitor name url) names urls;
  metricsHost = host: "${host}-metrics.${config.lab.domain}";
  monitoringTargets = {
    node = map (host: "${metricsHost host}:9100") [
      "pi-node-a"
      "pi-node-b"
      "pi-node-c"
    ];
    traefik = map (host: "${metricsHost host}:8082") [
      "pi-node-a"
      "pi-node-b"
      "pi-node-c"
    ];
    promtail =
      (map (host: "${metricsHost host}:9080") [
        "pi-node-a"
        "pi-node-b"
        "pi-node-c"
      ])
      ++ [
        "nas-host.${config.lab.domain}:9080"
      ];
    snmpExporter = [
      "${metricsHost "pi-node-b"}:9116"
    ];
    piholeExporter = map (host: "${metricsHost host}:9617") [
      "pi-node-a"
      "pi-node-b"
    ];
    cadvisor = map (host: "${metricsHost host}:8081") [
      "pi-node-a"
      "pi-node-b"
      "pi-node-c"
    ];
    githubProfile = [
      "${metricsHost "pi-node-b"}:9145"
    ];
    unpoller = [
      "${metricsHost "pi-node-b"}:9130"
    ];
  };
  availabilityTargets = {
    routed = {
      piholePrimary = "https://pihole01.${config.lab.domain}/admin/";
      piholeSecondary = "https://pihole02.${config.lab.domain}/admin/";
      diagramsNet = "https://diagramsnet.${config.lab.domain}/";
      excalidraw = "https://excalidraw.${config.lab.domain}/";
      owntracks = "http://owntracks.${config.lab.domain}:8084/";
      kuma = "https://kuma.${config.lab.domain}/";
      grafana = "https://grafana.${config.lab.domain}/";
      prometheus = "https://prometheus.${config.lab.domain}/";
      alertmanager = "https://alertmanager.${config.lab.domain}/";
      vikunja = "https://vikunja.${config.lab.domain}/";
      ghost = "https://blog.${config.lab.domain}/";
      gitea = "https://gitea.${config.lab.domain}/";
      homepage = "https://homepage.${config.lab.domain}/";
      archivebox = "https://archivebox.${config.lab.domain}/";
      outline = "https://outline.${config.lab.domain}/";
    };
    direct = {
      lokiReady = "http://loki.${config.lab.domain}:3100/ready";
      nodeMetrics = map (target: "http://${target}/metrics") monitoringTargets.node;
      promtailReady = map (target: "http://${target}/ready") monitoringTargets.promtail;
      snmpExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.snmpExporter;
      piholeExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.piholeExporter;
      githubProfileMetrics = map (target: "http://${target}/metrics") monitoringTargets.githubProfile;
      unpollerMetrics = map (target: "http://${target}/metrics") monitoringTargets.unpoller;
    };
  };
  kumaDesiredMonitors =
    [
      (mkHttpMonitor "Pi-hole Admin Primary" availabilityTargets.routed.piholePrimary)
      (mkHttpMonitor "Pi-hole Admin Secondary" availabilityTargets.routed.piholeSecondary)
      (mkHttpMonitor "diagrams.net" availabilityTargets.routed.diagramsNet)
      (mkHttpMonitor "Excalidraw" availabilityTargets.routed.excalidraw)
      (mkHttpMonitor "OwnTracks" availabilityTargets.routed.owntracks)
      (mkHttpMonitor "Kuma Self" availabilityTargets.routed.kuma)
      (mkHttpMonitor "Grafana" availabilityTargets.routed.grafana)
      (mkHttpMonitor "Prometheus" availabilityTargets.routed.prometheus)
      (mkHttpMonitor "Alertmanager" availabilityTargets.routed.alertmanager)
      (mkHttpMonitor "Vikunja" availabilityTargets.routed.vikunja)
      (mkHttpMonitor "Ghost" availabilityTargets.routed.ghost)
      (mkHttpMonitor "Gitea" availabilityTargets.routed.gitea)
      (mkHttpMonitor "Homepage" availabilityTargets.routed.homepage)
      (mkHttpMonitor "ArchiveBox" availabilityTargets.routed.archivebox)
      (mkKeywordMonitor "Loki Ready" availabilityTargets.direct.lokiReady "ready")
      (mkDnsMonitor "DNS Pi-hole" "google.com" "192.0.2.10")
    ]
    ++ (mkNamedHttpMonitors [
      "Node Exporter pi-node-a"
      "Node Exporter pi-node-b"
      "Node Exporter pi-node-c"
    ] availabilityTargets.direct.nodeMetrics)
    ++ (mkNamedHttpMonitors [
      "Promtail pi-node-a"
      "Promtail pi-node-b"
      "Promtail pi-node-c"
      "Promtail nas-host"
    ] availabilityTargets.direct.promtailReady)
    ++ (mkNamedHttpMonitors [
      "SNMP Exporter pi-node-b"
    ] availabilityTargets.direct.snmpExporterMetrics)
    ++ (mkNamedHttpMonitors [
      "Pi-hole Exporter pi-node-a"
      "Pi-hole Exporter pi-node-b"
    ] availabilityTargets.direct.piholeExporterMetrics)
    ++ (mkNamedHttpMonitors [
      "GitHub Profile Exporter"
    ] availabilityTargets.direct.githubProfileMetrics)
    ++ (mkNamedHttpMonitors [
      "Unpoller"
    ] availabilityTargets.direct.unpollerMetrics);
  uptimeKumaMonitorSync = pkgs.writeShellScript "uptime-kuma-monitor-sync" ''
    set -euo pipefail

    desired_json="/etc/uptime-kuma/desired-monitors.json"
    db_path="${config.services.uptimeKuma.dataDir}/kuma.db"

    if [ ! -s "$desired_json" ]; then
      exit 0
    fi

    # Existing deployments already have a DB. On a brand-new first boot, Kuma
    # creates it during initial startup, so there is nothing to sync yet.
    if [ ! -f "$db_path" ]; then
      exit 0
    fi

    ${pkgs.python3}/bin/python3 - <<'PY'
    import json
    import sqlite3
    from pathlib import Path

    desired = json.loads(Path("/etc/uptime-kuma/desired-monitors.json").read_text())
    conn = sqlite3.connect("${config.services.uptimeKuma.dataDir}/kuma.db")
    cur = conn.cursor()
    managed_marker = "[managed-by-nix-pi]"
    desired_names = set()

    for monitor in desired.get("monitors", []):
        name = monitor["name"]
        kind = monitor.get("kind")
        desired_names.add(name)

        row = cur.execute(
            "SELECT id FROM monitor WHERE name = ?",
            (name,),
        ).fetchone()

        common = {
            "active": 1,
            "interval": 60,
            "retry_interval": 60,
            "maxretries": 0,
        }

        if kind == "http":
            url = monitor["url"]
            values = {
                **common,
                "type": "http",
                "url": url,
                "ignore_tls": 1 if url.startswith("https://") else 0,
                "accepted_statuscodes_json": '["200-299"]',
                "dns_resolve_type": "A",
                "method": "GET",
                "conditions": "[]",
                "timeout": 0,
            }
        elif kind == "keyword":
            values = {
                **common,
                "type": "keyword",
                "url": monitor["url"],
                "keyword": monitor["keyword"],
                "ignore_tls": 0,
                "accepted_statuscodes_json": '["200-299"]',
                "dns_resolve_type": "A",
                "method": "GET",
                "conditions": "[]",
                "timeout": 0,
            }
        elif kind == "dns":
            values = {
                **common,
                "type": "dns",
                "url": "https://",
                "hostname": monitor["hostname"],
                "port": None,
                "dns_resolve_server": monitor["dnsResolveServer"],
                "dns_resolve_type": "A",
                "ignore_tls": 0,
                "accepted_statuscodes_json": '["200-299"]',
                "method": "GET",
                "conditions": "[]",
                "timeout": 0,
            }
        else:
            continue

        if row is None:
            if kind == "dns":
                cur.execute(
                    """
                    INSERT INTO monitor (
                        name, active, user_id, interval, url, type, weight,
                        hostname, port, maxretries, ignore_tls, upside_down,
                        maxredirects, accepted_statuscodes_json,
                        dns_resolve_server, dns_resolve_type, retry_interval, description,
                        method, conditions, timeout
                    ) VALUES (?, ?, 1, ?, ?, ?, 2000, ?, ?, ?, ?, 0, 10,
                              ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        name,
                        values["active"],
                        values["interval"],
                        values["url"],
                        values["type"],
                        values["hostname"],
                        values["port"],
                        values["maxretries"],
                        values["ignore_tls"],
                        values["accepted_statuscodes_json"],
                        values["dns_resolve_server"],
                        values["dns_resolve_type"],
                        values["retry_interval"],
                        managed_marker,
                        values["method"],
                        values["conditions"],
                        values["timeout"],
                    ),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO monitor (
                        name, active, user_id, interval, url, type, weight,
                        keyword, maxretries, ignore_tls, upside_down,
                        maxredirects, accepted_statuscodes_json, description,
                        dns_resolve_type, retry_interval, method, conditions,
                        timeout
                    ) VALUES (?, ?, 1, ?, ?, ?, 2000, ?, ?, ?, 0, 10,
                              ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        name,
                        values["active"],
                        values["interval"],
                        values["url"],
                        values["type"],
                        values.get("keyword"),
                        values["maxretries"],
                        values["ignore_tls"],
                        values["accepted_statuscodes_json"],
                        managed_marker,
                        values["dns_resolve_type"],
                        values["retry_interval"],
                        values["method"],
                        values["conditions"],
                        values["timeout"],
                    ),
                )
        else:
            cur.execute(
                """
                UPDATE monitor
                SET url = ?,
                    type = ?,
                    hostname = ?,
                    port = ?,
                    keyword = ?,
                    dns_resolve_server = ?,
                    active = ?,
                    interval = ?,
                    retry_interval = ?,
                    maxretries = ?,
                    ignore_tls = ?,
                    maxredirects = 10,
                    accepted_statuscodes_json = ?,
                    description = ?,
                    dns_resolve_type = ?,
                    method = ?,
                    conditions = ?,
                    timeout = ?
                WHERE id = ?
                """,
                (
                    values["url"],
                    values["type"],
                    values.get("hostname"),
                    values.get("port"),
                    values.get("keyword"),
                    values.get("dns_resolve_server"),
                    values["active"],
                    values["interval"],
                    values["retry_interval"],
                    values["maxretries"],
                    values["ignore_tls"],
                    values["accepted_statuscodes_json"],
                    managed_marker,
                    values["dns_resolve_type"],
                    values["method"],
                    values["conditions"],
                    values["timeout"],
                    row[0],
                ),
            )

    for monitor_id, name in cur.execute(
        "SELECT id, name FROM monitor WHERE description = ?",
        (managed_marker,),
    ).fetchall():
        if name not in desired_names:
            cur.execute("DELETE FROM monitor WHERE id = ?", (monitor_id,))

    conn.commit()
    conn.close()
    PY
  '';
  hasSmtpRelayModule = inputs.nix-services.services ? smtpRelay;
in ({
  imports = [
    inputs.nix-services.services.traefik
    inputs.nix-services.services.pihole
    inputs.nix-services.services.piholeSync
    inputs.nix-services.services.piholeExporter
    inputs.nix-services.services.cadvisor
    inputs.nix-services.services.alertmanager
    inputs.nix-services.services.prometheus
    inputs.nix-services.services.grafana
    inputs.nix-services.services.diagramsNet
    inputs.nix-services.services.excalidraw
    inputs.nix-services.services.uptimeKuma
    inputs.nix-services.services.vikunjaCompose
    inputs.nix-services.services.homepageDashboard
    inputs.nix-services.services.owntracksRecorder
    inputs.nix-services.services.ghost
    inputs.nix-services.services.promtail
    inputs.nix-services.services.snmpExporter
    inputs.nix-services.services.unpoller
  ] ++ lib.optional hasSmtpRelayModule inputs.nix-services.services.smtpRelay;

  networking.hostName = "pi-node-b";
  lab.nix.signingKeyFile = "/etc/nix/pi-node-b-priv.pem";
  networking.nameservers = lib.mkForce [
    "192.0.2.10"
    "1.1.1.1"
    "1.0.0.1"
  ];

  fileSystems."/srv/prometheus" = {
    device = "/dev/disk/by-uuid/3597e412-53d3-47a4-896e-0694c8e9bc0e";
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

  sops.secrets.grafana-admin-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "grafana-admin-password";
    path = "/run/secrets/grafana-admin-password";
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

  sops.secrets.unpoller-env = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "unpoller-env";
    path = "/run/secrets/unpoller.env";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.ghost-db-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "ghost-db-password";
    path = "/run/secrets/ghost-db-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.ghost-mail-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "ghost-mail-password";
    path = "/run/secrets/ghost-mail-password";
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
  services.traefik.plainHttp.enable = true;

  services.pihole = {
    enable = true;

    hostname = "pihole02.${config.lab.domain}";
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

  services.cadvisorCompose = {
    enable = true;
    listenAddress = "0.0.0.0";
    listenPort = 8081;
  };

  services.piholeSync = {
    enable = true;

    source = {
      host = "pi-node-a";
      user = "eduardo";
    };

    ssh.identityFile = config.sops.secrets.pihole-sync-ssh-key.path;

    schedule = "*-*-* 00,12:00:00";
    randomizedDelaySec = "15m";
  };

  services.diagramsNet = {
    enable = true;
    hostname = "diagramsnet.${config.lab.domain}";
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

  services.uptimeKuma = {
    enable = true;
    hostname = "kuma.${config.lab.domain}";
    tls = true;
  };

  services.vikunjaCompose = {
    enable = true;
    hostname = "vikunja.${config.lab.domain}";
    tls = true;
  };

  services.homepageDashboard = {
    enable = true;
    hostname = "homepage.${config.lab.domain}";
    tls = true;

    docker.enable = true;

    config = {
      settings = {
        title = "HHLab";
        description = "Internal service dashboard";
      };

      services = [
        {
          "Core" = [
            {
              "Homepage" = {
                href = availabilityTargets.routed.homepage;
                description = "Service dashboard";
                server = "local";
                container = "homepage";
              };
            }
            {
              "Pi-hole Secondary" = {
                href = availabilityTargets.routed.piholeSecondary;
                description = "Local DNS admin";
                server = "local";
                container = "pihole";
              };
            }
          ];
        }
        {
          "Monitoring" = [
            {
              "Grafana" = {
                href = availabilityTargets.routed.grafana;
                description = "Dashboards and metrics";
                server = "local";
                container = "grafana";
              };
            }
            {
              "Prometheus" = {
                href = availabilityTargets.routed.prometheus;
                description = "Metrics collection";
                server = "local";
                container = "prometheus";
              };
            }
            {
              "Alertmanager" = {
                href = availabilityTargets.routed.alertmanager;
                description = "Alert routing";
                server = "local";
                container = "alertmanager";
              };
            }
          ];
        }
        {
          "Workspace" = [
            {
              "diagrams.net" = {
                href = availabilityTargets.routed.diagramsNet;
                description = "Diagram editor";
                server = "local";
                container = "diagrams-net";
              };
            }
            {
              "Excalidraw" = {
                href = availabilityTargets.routed.excalidraw;
                description = "Whiteboard";
                server = "local";
                container = "excalidraw";
              };
            }
            {
              "Vikunja" = {
                href = availabilityTargets.routed.vikunja;
                description = "Tasks";
                server = "local";
                container = "vikunja";
              };
            }
          ];
        }
        {
          "Apps" = [
            {
              "Uptime Kuma" = {
                href = availabilityTargets.routed.kuma;
                description = "Availability checks";
                server = "local";
                container = "uptime-kuma";
              };
            }
            {
              "OwnTracks" = {
                href = availabilityTargets.routed.owntracks;
                description = "Location recorder";
                server = "local";
                container = "owntracks-recorder";
              };
            }
            {
              "Ghost" = {
                href = availabilityTargets.routed.ghost;
                description = "Internal blog";
                server = "local";
                container = "ghost";
              };
            }
          ];
        }
        {
          "pi-node-a" = [
            {
              "Pi-hole Primary" = {
                href = availabilityTargets.routed.piholePrimary;
                description = "Primary DNS admin (health in Uptime Kuma)";
              };
            }
          ];
        }
        {
          "nas-host" = [
            {
              "Gitea" = {
                href = availabilityTargets.routed.gitea;
                description = "Code forge (health in Uptime Kuma)";
              };
            }
            {
              "ArchiveBox" = {
                href = availabilityTargets.routed.archivebox;
                description = "Web archive (health in Uptime Kuma)";
              };
            }
            {
              "Outline" = {
                href = availabilityTargets.routed.outline;
                description = "Knowledge base";
              };
            }
          ];
        }
      ];
    };
  };

  services.owntracksRecorder = {
    enable = true;
    hostname = "owntracks.${config.lab.domain}";
    dataDir = "/srv/prometheus/owntracks";
    tls = false;
    entryPoint = "webplain";
  };

  systemd.services.uptime-kuma.serviceConfig.ExecStartPre = lib.mkAfter [
    uptimeKumaMonitorSync
  ];

  environment.etc."uptime-kuma/desired-monitors.json".text = builtins.toJSON {
    version = 1;
    managedBy = "nix-pi";
    note = "Declarative source-of-truth for host-managed Uptime Kuma monitors. The uptime-kuma startup hook syncs and prunes tagged monitors from the SQLite database on existing deployments.";
    monitors = kumaDesiredMonitors;
  };

  systemd.services.uptime-kuma.restartTriggers = lib.mkAfter [
    config.environment.etc."uptime-kuma/desired-monitors.json".source
  ];

  services.ghost = {
    enable = true;
    hostname = "blog.${config.lab.domain}";
    tls = true;
    dataDir = "/var/lib/ghost";

    database = {
      host = "nas-host.${config.lab.domain}";
      port = 3306;
      name = "ghost";
      user = "ghost";
      passwordFile = config.sops.secrets.ghost-db-password.path;
    };

    mail = {
      enable = true;
      from = "eduardoshanahan@gmail.com";
      host = if hasSmtpRelayModule then "smtp-relay.${config.lab.domain}" else "smtp.gmail.com";
      port = if hasSmtpRelayModule then 2525 else 465;
      secure = if hasSmtpRelayModule then false else true;
      user = if hasSmtpRelayModule then "" else "eduardoshanahan@gmail.com";
      passwordFile = config.sops.secrets.ghost-mail-password.path;
    };
  };

  services.grafanaCompose = {
    enable = true;
    hostname = "grafana.${config.lab.domain}";
    adminPasswordFile = config.sops.secrets.grafana-admin-password.path;
    tls = true;
    provisioning.datasources.loki.url = "http://loki.${config.lab.domain}:3100";
    backup = {
      enable = true;
      targetDir = "/srv/prometheus/grafana-backups";
      schedule = "daily";
      keepDays = 14;
    };
  };

  services.alertmanager = {
    enable = true;
    hostname = "alertmanager.${config.lab.domain}";
    tls = true;

    notifications = {
      # Enable after adding these secrets in sops and wiring sops.secrets entries.
      email = {
        enable = false;
        smarthost = if hasSmtpRelayModule then "smtp-relay.${config.lab.domain}:2525" else "smtp.gmail.com:587";
        requireTls = !hasSmtpRelayModule;
        from = "homelab-alerts@example.com";
        to = "you@example.com";
        authUsername = "homelab-alerts@example.com";
        authPasswordFile = "/run/secrets/alertmanager-smtp-password";
      };
      telegram = {
        enable = false;
        botTokenFile = "/run/secrets/alertmanager-telegram-bot-token";
        chatId = 123456789;
      };
    };
  };

  services.prometheusCompose = {
    enable = true;
    hostname = "prometheus.${config.lab.domain}";
    dataDir = "/srv/prometheus/data";
    retentionTime = "30d";

    scrape = {
      nodeTargets = monitoringTargets.node;
      synologyNodeTargets = [
        "nas-host.${config.lab.domain}:9100"
      ];
      synologySnmpTargets = [
        "nas-host.${config.lab.domain}"
        "nas2.${config.lab.domain}"
      ];
      synologySnmpSystemTargets = [
        "nas2.${config.lab.domain}"
      ];
      synologySnmpMemoryTargets = [
        "nas2.${config.lab.domain}"
      ];
      synologySnmpStorageTargets = [
        "nas2.${config.lab.domain}"
      ];
      synologySnmpNetworkTargets = [
        "nas2.${config.lab.domain}"
      ];
      synologySnmpLoadTargets = [
        "nas2.${config.lab.domain}"
      ];
      synologySnmpUptimeTargets = [
        "nas2.${config.lab.domain}"
      ];
      synologySnmpExporterAddress = "pi-node-b-metrics.${config.lab.domain}:9116";
      synologySnmpModule = "synology";
      synologySnmpAuth = "public_v2";
      lokiTargets = [
        "loki.${config.lab.domain}:3100"
      ];
      traefikTargets = monitoringTargets.traefik;
      promtailTargets = monitoringTargets.promtail;
      snmpExporterTargets = monitoringTargets.snmpExporter;
      grafanaTargets = [
        "grafana:3000"
      ];
      piholeExporterTargets = monitoringTargets.piholeExporter;
      cadvisorTargets = monitoringTargets.cadvisor;
      giteaTargets = [
        "gitea.${config.lab.domain}:3000"
      ];
      githubProfileTargets = monitoringTargets.githubProfile;
      unpollerTargets = monitoringTargets.unpoller;
    };

    tls = true;
  };

  services.promtailCompose = {
    enable = true;
    lokiPushUrl = "http://loki.internal.example:3100/loki/api/v1/push";
  };

  services.snmpExporterCompose = {
    enable = true;
    listenAddress = "0.0.0.0";
    listenPort = 9116;
    snmpV2Community = "7fjeuibngymx";
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" "filesystem" "meminfo" "netdev" "loadavg" "hwmon" ];
  };

  systemd.services.github-profile-exporter = {
    description = "GitHub profile metrics exporter";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${githubProfileExporter}";
      Restart = "always";
      RestartSec = 10;
      DynamicUser = true;
      Environment = [
        "GITHUB_PROFILE_USERNAME=eduardoshanahan"
        "GITHUB_PROFILE_EXPORTER_PORT=9145"
        "GITHUB_PROFILE_CACHE_TTL_SECONDS=3600"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [
    53
    80
    443
    8084
    8081
    8082
    9080
    9100
    9116
    9617
    9130
    9145
  ];
  networking.firewall.allowedUDPPorts = [
    53
  ];
  services.unpollerCompose = {
    enable = true;
    controller.url = "https://ucg-max.internal.example";
    # UCG/UniFi controllers often use internal certs not trusted in containers.
    controller.verifySsl = false;
    secretFile = config.sops.secrets.unpoller-env.path;
    listenAddress = "0.0.0.0";
    listenPort = 9130;
  };
} // lib.optionalAttrs hasSmtpRelayModule {
  services.smtpRelayCompose = {
    enable = true;
    hostname = "smtp-relay.${config.lab.domain}";
    listenAddress = "0.0.0.0";
    listenPort = 2525;
    openFirewall = true;

    upstream = {
      host = "smtp.gmail.com";
      port = 587;
      username = "eduardoshanahan@gmail.com";
      passwordFile = config.sops.secrets.ghost-mail-password.path;
    };

    allowedSenderDomains = [
      config.lab.domain
      "gmail.com"
      "example.com"
    ];
  };
})
