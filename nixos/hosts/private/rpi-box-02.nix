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
  mkPortMonitor = name: hostname: port: {
    inherit name hostname port;
    kind = "port";
  };
  mkNamedHttpMonitors = names: urls:
    lib.zipListsWith (name: url: mkHttpMonitor name url) names urls;
  mkNamedPortMonitors = names: targets:
    lib.zipListsWith (name: target: mkPortMonitor name target.host target.port) names targets;
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
    postgresExporter = [
      "${metricsHost "pi-node-b"}:9187"
    ];
    redisExporter = [
      "${metricsHost "pi-node-b"}:9121"
    ];
    mysqlExporter = [
      "${metricsHost "pi-node-b"}:9104"
    ];
    mongodbExporter = [
      "${metricsHost "pi-node-b"}:9216"
    ];
    dolt = [
      "dolt.${config.lab.domain}:11228"
    ];
  };
  availabilityTargets = {
    routed = {
      piholePrimary = "https://pihole01.${config.lab.domain}/admin/";
      piholeSecondary = "https://pihole02.${config.lab.domain}/admin/";
      diagramsNet = "https://diagramsnet.${config.lab.domain}/";
      excalidraw = "https://excalidraw.${config.lab.domain}/";
      fossflow = "https://fossflow.${config.lab.domain}/";
      searxng = "https://searxng.${config.lab.domain}/";
      owntracks = "http://owntracks.${config.lab.domain}:8084/";
      kuma = "https://kuma.${config.lab.domain}/";
      kumaDashboard = "https://kuma.${config.lab.domain}/dashboard";
      grafana = "https://grafana.${config.lab.domain}/";
      prometheus = "https://prometheus.${config.lab.domain}/";
      alertmanager = "https://alertmanager.${config.lab.domain}/";
      vikunja = "https://vikunja.${config.lab.domain}/";
      ghost = "https://blog.${config.lab.domain}/";
      gitea = "https://gitea.${config.lab.domain}/";
      woodpecker = "https://woodpecker.${config.lab.domain}/";
      homepage = "https://homepage.${config.lab.domain}/";
      n8n = "https://n8n.${config.lab.domain}/";
      archivebox = "https://archivebox.${config.lab.domain}/";
      jellyfin = "https://jellyfin.${config.lab.domain}/";
      outline = "https://outline.${config.lab.domain}/";
      homeAssistant = "https://homeassistant.${config.lab.domain}/";
      authentik = "https://authentik.${config.lab.domain}/";
      timeTagger = "https://timetagger.${config.lab.domain}/";
      traggo = "https://traggo.${config.lab.domain}/";
      karakeep = "https://karakeep.${config.lab.domain}/";
      dozzle = "https://dozzle.${config.lab.domain}/";
      d2 = "https://d2.${config.lab.domain}/";
      paperless = "https://paperless.${config.lab.domain}/";
    };
    direct = {
      lokiReady = "http://loki.${config.lab.domain}:3100/ready";
      tikaVersion = "http://tika.${config.lab.domain}:9998/version";
      gotenbergHealth = "http://gotenberg.${config.lab.domain}:3001/health";
      doltMetrics = "http://dolt.${config.lab.domain}:11228/metrics";
      nodeMetrics = map (target: "http://${target}/metrics") monitoringTargets.node;
      promtailReady = map (target: "http://${target}/ready") monitoringTargets.promtail;
      snmpExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.snmpExporter;
      piholeExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.piholeExporter;
      githubProfileMetrics = map (target: "http://${target}/metrics") monitoringTargets.githubProfile;
      unpollerMetrics = map (target: "http://${target}/metrics") monitoringTargets.unpoller;
      postgresExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.postgresExporter;
      redisExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.redisExporter;
      mysqlExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.mysqlExporter;
      mongodbExporterMetrics = map (target: "http://${target}/metrics") monitoringTargets.mongodbExporter;
    };
  };
  kumaDesiredMonitors =
    [
      (mkHttpMonitor "Pi-hole Admin Primary" availabilityTargets.routed.piholePrimary)
      (mkHttpMonitor "Pi-hole Admin Secondary" availabilityTargets.routed.piholeSecondary)
      (mkHttpMonitor "diagrams.net" availabilityTargets.routed.diagramsNet)
      (mkHttpMonitor "Excalidraw" availabilityTargets.routed.excalidraw)
      (mkHttpMonitor "FossFLOW" availabilityTargets.routed.fossflow)
      (mkHttpMonitor "SearXNG" availabilityTargets.routed.searxng)
      (mkHttpMonitor "OwnTracks" availabilityTargets.routed.owntracks)
      (mkHttpMonitor "Kuma Self" availabilityTargets.routed.kumaDashboard)
      (mkHttpMonitor "Grafana" availabilityTargets.routed.grafana)
      (mkHttpMonitor "Prometheus" availabilityTargets.routed.prometheus)
      (mkHttpMonitor "Alertmanager" availabilityTargets.routed.alertmanager)
      (mkHttpMonitor "Vikunja" availabilityTargets.routed.vikunja)
      (mkHttpMonitor "Ghost" availabilityTargets.routed.ghost)
      (mkHttpMonitor "Gitea" availabilityTargets.routed.gitea)
      (mkHttpMonitor "Woodpecker" availabilityTargets.routed.woodpecker)
      (mkHttpMonitor "Homepage" availabilityTargets.routed.homepage)
      (mkHttpMonitor "n8n" availabilityTargets.routed.n8n)
      (mkHttpMonitor "ArchiveBox" availabilityTargets.routed.archivebox)
      (mkHttpMonitor "Jellyfin" availabilityTargets.routed.jellyfin)
      (mkHttpMonitor "Outline" availabilityTargets.routed.outline)
      (mkHttpMonitor "Home Assistant" availabilityTargets.routed.homeAssistant)
      (mkHttpMonitor "Authentik" availabilityTargets.routed.authentik)
      (mkHttpMonitor "TimeTagger" availabilityTargets.routed.timeTagger)
      (mkHttpMonitor "Traggo" availabilityTargets.routed.traggo)
      (mkHttpMonitor "KaraKeep" availabilityTargets.routed.karakeep)
      (mkHttpMonitor "Dozzle" availabilityTargets.routed.dozzle)
      (mkHttpMonitor "D2" availabilityTargets.routed.d2)
      (mkHttpMonitor "Paperless" availabilityTargets.routed.paperless)
      (mkPortMonitor "SMTP Relay" "smtp-relay.${config.lab.domain}" 2525)
      (mkPortMonitor "nas-host Postgres" "postgres.${config.lab.domain}" 5433)
      (mkPortMonitor "nas-host Redis" "redis.${config.lab.domain}" 6379)
      (mkPortMonitor "nas-host Mongo" "mongo.${config.lab.domain}" 27017)
      (mkPortMonitor "nas-host Dolt SQL" "dolt.${config.lab.domain}" 3307)
      (mkPortMonitor "nas-host MySQL" "nas-host.${config.lab.domain}" 3306)
      (mkPortMonitor "nas-host Docker Socket Proxy" "nas-host.${config.lab.domain}" 2375)
      (mkKeywordMonitor "Loki Ready" availabilityTargets.direct.lokiReady "ready")
      (mkKeywordMonitor "Tika Version" availabilityTargets.direct.tikaVersion "Apache Tika")
      (mkKeywordMonitor "Gotenberg Health" availabilityTargets.direct.gotenbergHealth "\"status\":\"up\"")
      (mkKeywordMonitor "Dolt Metrics" availabilityTargets.direct.doltMetrics "dss_concurrent_connections")
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
    ++ (mkNamedPortMonitors [
      "Docker Socket Proxy pi-node-a"
      "Docker Socket Proxy pi-node-c"
    ] [
      {
        host = "pi-node-a.${config.lab.domain}";
        port = 2375;
      }
      {
        host = "pi-node-c.${config.lab.domain}";
        port = 2375;
      }
    ])
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
    ] availabilityTargets.direct.unpollerMetrics)
    ++ lib.optionals hasPostgresExporterModule (
      mkNamedHttpMonitors [
        "Postgres Exporter pi-node-b"
      ] availabilityTargets.direct.postgresExporterMetrics
    )
    ++ lib.optionals (hasRedisExporterModule && enableRedisExporter) (
      mkNamedHttpMonitors [
        "Redis Exporter pi-node-b"
      ] availabilityTargets.direct.redisExporterMetrics
    )
    ++ lib.optionals (hasMysqlExporterModule && enableMysqlExporter) (
      mkNamedHttpMonitors [
        "MySQL Exporter pi-node-b"
      ] availabilityTargets.direct.mysqlExporterMetrics
    )
    ++ lib.optionals hasMongoExporterModule (
      mkNamedHttpMonitors [
        "MongoDB Exporter pi-node-b"
      ] availabilityTargets.direct.mongodbExporterMetrics
    );
  uptimeKumaMonitorSync = pkgs.writeShellScript "uptime-kuma-monitor-sync" ''
    set -euo pipefail

    desired_json="/etc/uptime-kuma/desired-monitors.json"
    if [ ! -s "$desired_json" ]; then
      exit 0
    fi

    ${pkgs.python3.withPackages (ps: [ ps.pymysql ])}/bin/python3 - <<'PY'
import json
import sqlite3
import sys
from pathlib import Path
import pymysql

desired = json.loads(Path("/etc/uptime-kuma/desired-monitors.json").read_text())
managed_marker = "[managed-by-nix-pi]"


def build_values(monitor):
    kind = monitor.get("kind")
    common = {
        "active": 1,
        "interval": 60,
        "retry_interval": 60,
        "maxretries": 0,
    }

    if kind == "http":
        url = monitor["url"]
        return kind, {
            **common,
            "type": "http",
            "url": url,
            "ignore_tls": 1 if url.startswith("https://") else 0,
            "accepted_statuscodes_json": (
                '["200-299","401"]' if monitor["name"] == "D2"
                else '["200-299"]'
            ),
            "dns_resolve_type": "A",
            "method": "GET",
            "conditions": "[]",
            "timeout": 0,
        }
    if kind == "keyword":
        return kind, {
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
    if kind == "dns":
        return kind, {
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
    if kind == "port":
        return kind, {
            **common,
            "type": "port",
            "url": "https://",
            "hostname": monitor["hostname"],
            "port": monitor["port"],
            "dns_resolve_server": None,
            "dns_resolve_type": "A",
            "ignore_tls": 0,
            "accepted_statuscodes_json": '["200-299"]',
            "method": "GET",
            "conditions": "[]",
            "timeout": 0,
        }
    return None, None


def sync_connection(conn, placeholder):
    desired_names = set()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id FROM user ORDER BY id LIMIT 1")
        user_row = cur.fetchone()
        if not user_row:
            return 0
        user_id = user_row[0]
        managed_count = 0

        for monitor in desired.get("monitors", []):
            name = monitor["name"]
            kind, values = build_values(monitor)
            if kind is None:
                continue

            desired_names.add(name)
            cur.execute(f"SELECT id FROM monitor WHERE name = {placeholder}", (name,))
            row = cur.fetchone()

            if row is None:
                if kind in ("dns", "port"):
                    cur.execute(
                        f"""
                        INSERT INTO monitor (
                            name, active, user_id, `interval`, url, type, weight,
                            hostname, port, maxretries, ignore_tls, upside_down,
                            maxredirects, accepted_statuscodes_json,
                            dns_resolve_server, dns_resolve_type, retry_interval, description,
                            method, conditions, timeout
                        ) VALUES ({placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, 2000,
                                  {placeholder}, {placeholder}, {placeholder}, {placeholder}, 0, 10,
                                  {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder})
                        """,
                        (
                            name,
                            values["active"],
                            user_id,
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
                        f"""
                        INSERT INTO monitor (
                            name, active, user_id, `interval`, url, type, weight,
                            keyword, maxretries, ignore_tls, upside_down,
                            maxredirects, accepted_statuscodes_json, description,
                            dns_resolve_type, retry_interval, method, conditions, timeout
                        ) VALUES ({placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, 2000,
                                  {placeholder}, {placeholder}, {placeholder}, 0, 10,
                                  {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder}, {placeholder})
                        """,
                        (
                            name,
                            values["active"],
                            user_id,
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
                managed_count += 1
            else:
                cur.execute(
                    f"""
                    UPDATE monitor
                    SET url = {placeholder},
                        type = {placeholder},
                        hostname = {placeholder},
                        port = {placeholder},
                        keyword = {placeholder},
                        dns_resolve_server = {placeholder},
                        active = {placeholder},
                        `interval` = {placeholder},
                        retry_interval = {placeholder},
                        maxretries = {placeholder},
                        ignore_tls = {placeholder},
                        maxredirects = 10,
                        accepted_statuscodes_json = {placeholder},
                        description = {placeholder},
                        dns_resolve_type = {placeholder},
                        method = {placeholder},
                        conditions = {placeholder},
                        timeout = {placeholder}
                    WHERE id = {placeholder}
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
                managed_count += 1

        cur.execute(f"SELECT id, name FROM monitor WHERE description = {placeholder}", (managed_marker,))
        for monitor_id, name in cur.fetchall():
            if name not in desired_names:
                cur.execute(f"DELETE FROM monitor WHERE id = {placeholder}", (monitor_id,))
    finally:
        cur.close()
    conn.commit()
    return managed_count


updated_any = False
password_path = Path("${config.sops.secrets.kuma-db-password.path}")
if password_path.is_file():
    password = password_path.read_text().strip()
    if password:
        try:
            mariadb_conn = pymysql.connect(
                host="${config.services.uptimeKuma.database.mariadb.host}",
                port=${toString config.services.uptimeKuma.database.mariadb.port},
                user="${config.services.uptimeKuma.database.mariadb.user}",
                password=password,
                database="${config.services.uptimeKuma.database.mariadb.name}",
                charset="utf8mb4",
                autocommit=False,
            )
            sync_connection(mariadb_conn, "%s")
            mariadb_conn.close()
            updated_any = True
        except Exception as exc:
            print(f"uptime-kuma-monitor-sync: mariadb sync skipped: {exc}", file=sys.stderr)

sqlite_path = Path("/srv/uptime-kuma/kuma.db")
if sqlite_path.is_file():
    sqlite_conn = sqlite3.connect(sqlite_path)
    try:
        sync_connection(sqlite_conn, "?")
        updated_any = True
    finally:
        sqlite_conn.close()

if not updated_any:
    raise SystemExit(0)
PY
  '';
  hasSmtpRelayModule = inputs.nix-services.services ? smtpRelay;
  hasPostgresExporterModule = inputs.nix-services.services ? postgresExporterCompose;
  hasRedisExporterModule = inputs.nix-services.services ? redisExporterCompose;
  hasMysqlExporterModule = inputs.nix-services.services ? mysqlExporterCompose;
  hasMongoExporterModule = inputs.nix-services.services ? mongodbExporterCompose;
  hasDozzleModule = inputs.nix-services.services ? dozzleCompose;
  hasD2Module = inputs.nix-services.services ? d2Compose;
  hasN8nModule = inputs.nix-services.services ? n8nCompose;
  hasWoodpeckerModule = inputs.nix-services.services ? woodpeckerCompose;
  enableRedisExporter = true;
  enableMysqlExporter = true;
in lib.recursiveUpdate ({
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
    inputs.nix-services.services.fossflowCompose
    inputs.nix-services.services.searxngCompose
    inputs.nix-services.services.uptimeKuma
    inputs.nix-services.services.vikunjaCompose
    inputs.nix-services.services.homepageDashboard
    inputs.nix-services.services.owntracksRecorder
    inputs.nix-services.services.ghost
    inputs.nix-services.services.homeAssistant
    inputs.nix-services.services.authentikCompose
    inputs.nix-services.services.timeTaggerCompose
    inputs.nix-services.services.traggoCompose
    inputs.nix-services.services.promtail
    inputs.nix-services.services.snmpExporter
    inputs.nix-services.services.unpoller
  ]
  ++ lib.optional hasSmtpRelayModule inputs.nix-services.services.smtpRelay
  ++ lib.optional hasPostgresExporterModule inputs.nix-services.services.postgresExporterCompose
  ++ lib.optional hasRedisExporterModule inputs.nix-services.services.redisExporterCompose
  ++ lib.optional hasMysqlExporterModule inputs.nix-services.services.mysqlExporterCompose
  ++ lib.optional hasMongoExporterModule inputs.nix-services.services.mongodbExporterCompose
  ++ lib.optional hasDozzleModule inputs.nix-services.services.dozzleCompose
  ++ lib.optional hasD2Module inputs.nix-services.services.d2Compose
  ++ lib.optional hasN8nModule inputs.nix-services.services.n8nCompose
  ++ lib.optional hasWoodpeckerModule inputs.nix-services.services.woodpeckerCompose;

  networking.hostName = "pi-node-b";
  lab.nix.signingKeyFile = "/etc/nix/pi-node-b-priv.pem";
  networking.nameservers = lib.mkForce [
    "192.0.2.10"
    "192.0.2.10"
  ];

  fileSystems."/srv" = {
    device = "/dev/disk/by-uuid/3597e412-53d3-47a4-896e-0694c8e9bc0e";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems."/var/lib/diagrams-net" = {
    device = "/srv/diagrams-net";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/srv" ];
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

  sops.secrets.smtp-relay-upstream-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "smtp-relay-upstream-password";
    path = "/run/secrets/smtp-relay-upstream-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.alertmanager-smtp-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "alertmanager-smtp-password";
    path = "/run/secrets/alertmanager-smtp-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.vikunja-db-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "vikunja-db-password";
    path = "/run/secrets/vikunja-db-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.n8n-db-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "n8n-db-password";
    path = "/run/secrets/n8n-db-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.n8n-encryption-key = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "n8n-encryption-key";
    path = "/run/secrets/n8n-encryption-key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.kuma-db-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "kuma-db-password";
    path = "/run/secrets/kuma-db-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.homeassistant-recorder-db-url = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "homeassistant-recorder-db-url";
    path = "/run/secrets/homeassistant-recorder-db-url";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.grafana-db-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "grafana-db-password";
    path = "/run/secrets/grafana-db-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.redis-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "redis-password";
    path = "/run/secrets/redis-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.mongodb-exporter-uri = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "mongodb-exporter-uri";
    path = "/run/secrets/mongodb-exporter-uri";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.grafana-oidc-client-id = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "grafana-oidc-client-id";
    path = "/run/secrets/grafana-oidc-client-id";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.grafana-oidc-client-secret = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "grafana-oidc-client-secret";
    path = "/run/secrets/grafana-oidc-client-secret";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.vikunja-oidc-client-id = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "vikunja-oidc-client-id";
    path = "/run/secrets/vikunja-oidc-client-id";
    owner = "root";
    group = "root";
    mode = "0440";
  };

  sops.secrets.vikunja-oidc-client-secret = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "vikunja-oidc-client-secret";
    path = "/run/secrets/vikunja-oidc-client-secret";
    owner = "root";
    group = "root";
    mode = "0440";
  };

  sops.secrets.authentik-db-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "authentik-db-password";
    path = "/run/secrets/authentik-db-password";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.authentik-secret-key = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "authentik-secret-key";
    path = "/run/secrets/authentik-secret-key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.authentik-bootstrap-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "authentik-bootstrap-password";
    path = "/run/secrets/authentik-bootstrap-password";
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

  sops.secrets.woodpecker-agent-secret = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "woodpecker-agent-secret";
    path = "/run/secrets/woodpecker-agent-secret";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.woodpecker-gitea-client = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "woodpecker-gitea-client";
    path = "/run/secrets/woodpecker-gitea-client";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.woodpecker-gitea-secret = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "woodpecker-gitea-secret";
    path = "/run/secrets/woodpecker-gitea-secret";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets.woodpecker-postgres-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "woodpecker-postgres-password";
    path = "/run/secrets/woodpecker-postgres-password";
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

  services.fossflowCompose = {
    enable = true;
    hostname = "fossflow.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/fossflow";
  };

  services.searxngCompose = {
    enable = true;
    hostname = "searxng.${config.lab.domain}";
    tls = true;
    configDir = "/srv/searxng/config";
    dataDir = "/srv/searxng/data";
  };

  services.homeAssistant = {
    enable = true;
    hostname = "homeassistant.${config.lab.domain}";
    dataDir = "/srv/home-assistant";
    tls = true;
    image.tag = "2026.3.0";
    reverseProxy.trustedProxies = [ "172.18.0.0/16" ];
    recorder.dbUrlFile = config.sops.secrets.homeassistant-recorder-db-url.path;
  };

  services.authentikCompose = {
    enable = true;
    hostname = "authentik.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/authentik";
    metrics = {
      enable = true;
      listenAddress = "0.0.0.0:9300";
    };
    database.postgres = {
      host = "postgres.${config.lab.domain}";
      port = 5433;
      name = "authentik";
      user = "authentik";
      passwordFile = config.sops.secrets.authentik-db-password.path;
      sslMode = "disable";
    };
    secretKeyFile = config.sops.secrets.authentik-secret-key.path;
    bootstrap = {
      email = "contact@primary.example";
      passwordFile = config.sops.secrets.authentik-bootstrap-password.path;
    };
  };

  services.timeTaggerCompose = {
    enable = true;
    hostname = "timetagger.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/timetagger";
    credentials = "eduardo:$2b$12$VjK7w0lS.IfPf8GpnhfzPOUaCLBZRnXb/D0z9NYjnvUvBffv2Zobe";
    image = {
      tag = "latest";
      allowMutableTag = true;
    };
  };

  services.traggoCompose = {
    enable = true;
    hostname = "traggo.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/traggo";
    admin = {
      username = "eduardo";
      passwordFile = config.sops.secrets.traggo-admin-password.path;
    };
  };

  services.woodpeckerCompose = {
    enable = true;
    hostname = "woodpecker.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/woodpecker";
    openRegistration = false;
    adminUsers = [ "eduardo" ];
    gitea = {
      url = "https://gitea.${config.lab.domain}";
      clientIdFile = config.sops.secrets.woodpecker-gitea-client.path;
      clientSecretFile = config.sops.secrets.woodpecker-gitea-secret.path;
    };
    database.postgres = {
      host = "postgres.${config.lab.domain}";
      port = 5433;
      name = "woodpecker";
      user = "woodpecker";
      passwordFile = config.sops.secrets.woodpecker-postgres-password.path;
      sslMode = "disable";
    };
    agent = {
      hostname = "pi-node-b";
      secretFile = config.sops.secrets.woodpecker-agent-secret.path;
      maxWorkflows = 1;
      server = "woodpecker-server:9000";
      backendDockerVolumes = [ "/etc/ssl/certs:/etc/ssl/certs:ro" ];
    };
  };

  services.dozzleCompose = {
    enable = true;
    hostname = "dozzle.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/dozzle";
    remoteHosts = [
      "tcp://pi-node-a.${config.lab.domain}:2375|pi-node-a"
      "tcp://pi-node-c.${config.lab.domain}:2375|pi-node-c"
      "tcp://nas-host.${config.lab.domain}:2375|nas-host"
    ];
  };

  services.uptimeKuma = {
    enable = true;
    hostname = "kuma.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/uptime-kuma";
    database = {
      type = "sqlite";
      mariadb = {
        host = "nas-host.${config.lab.domain}";
        port = 3306;
        name = "uptime_kuma";
        user = "uptime_kuma";
        passwordFile = config.sops.secrets.kuma-db-password.path;
      };
    };
  };

  services.vikunjaCompose = {
    enable = true;
    hostname = "vikunja.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/vikunja";
    metrics.enable = true;
    auth = {
      local.enable = true;
      openid = {
        enable = true;
        providerKey = "authentik";
        name = "Authentik";
        authUrl = "https://authentik.${config.lab.domain}/application/o/vikunja/";
        clientIdFile = config.sops.secrets.vikunja-oidc-client-id.path;
        clientSecretFile = config.sops.secrets.vikunja-oidc-client-secret.path;
        scopes = "openid profile email";
        usernameFallback = true;
        emailFallback = true;
      };
    };
    database = {
      type = "postgres";
      postgres = {
        host = "postgres.${config.lab.domain}";
        port = 5433;
        name = "vikunja";
        user = "vikunja";
        passwordFile = config.sops.secrets.vikunja-db-password.path;
        sslMode = "disable";
      };
    };
  };

  services.n8nCompose = lib.mkIf hasN8nModule {
    enable = true;
    hostname = "n8n.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/n8n";
    database.postgres = {
      host = "postgres.${config.lab.domain}";
      port = 5433;
      name = "n8n";
      user = "n8n";
      passwordFile = config.sops.secrets.n8n-db-password.path;
    };
    encryptionKeyFile = config.sops.secrets.n8n-encryption-key.path;
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
            {
              "SMTP Relay" = {
                href = availabilityTargets.routed.kuma;
                description = "Shared relay (TCP 2525, monitored in Kuma)";
                server = "local";
                container = "smtp-relay";
              };
            }
            {
              "Loki" = {
                href = availabilityTargets.direct.lokiReady;
                description = "Log storage readiness";
                server = "pi-node-c";
                container = "loki";
              };
            }
            {
              "SNMP Exporter" = {
                href = "http://${metricsHost "pi-node-b"}:9116/metrics";
                description = "Synology SNMP metrics endpoint";
                server = "local";
                container = "snmp-exporter";
              };
            }
            {
              "Unpoller" = {
                href = "http://${metricsHost "pi-node-b"}:9130/metrics";
                description = "UniFi metrics endpoint";
                server = "local";
                container = "unpoller";
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
              "FossFLOW" = {
                href = availabilityTargets.routed.fossflow;
                description = "Isometric diagram editor";
                server = "local";
                container = "fossflow";
              };
            }
            {
              "SearXNG" = {
                href = availabilityTargets.routed.searxng;
                description = "Private metasearch";
                server = "local";
                container = "searxng";
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
            {
              "D2" = {
                href = availabilityTargets.routed.d2;
                description = "Diagram-as-code workspace";
                server = "local";
                container = "d2";
              };
            }
            {
              "Paperless" = {
                href = availabilityTargets.routed.paperless;
                description = "Document management and OCR";
                server = "nas-host";
                container = "nas-host-paperless";
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
              "n8n" = {
                href = availabilityTargets.routed.n8n;
                description = "Workflow automation";
                server = "local";
                container = "n8n";
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
                container = "ghost-blog";
              };
            }
            {
              "Home Assistant" = {
                href = availabilityTargets.routed.homeAssistant;
                description = "Home automation";
                server = "local";
                container = "home-assistant";
              };
            }
            {
              "Authentik" = {
                href = availabilityTargets.routed.authentik;
                description = "Identity provider";
                server = "local";
                container = "authentik-server";
              };
            }
            {
              "TimeTagger" = {
                href = availabilityTargets.routed.timeTagger;
                description = "Time tracking";
                server = "local";
                container = "timetagger";
              };
            }
            {
              "Traggo" = {
                href = availabilityTargets.routed.traggo;
                description = "Task and time management";
                server = "local";
                container = "traggo";
              };
            }
            {
              "Dozzle" = {
                href = availabilityTargets.routed.dozzle;
                description = "Docker logs viewer";
                server = "local";
                container = "dozzle";
              };
            }
            {
              "Woodpecker" = {
                href = availabilityTargets.routed.woodpecker;
                description = "CI server and runner control plane";
                server = "local";
                container = "woodpecker-server";
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
                server = "pi-node-a";
                container = "pihole";
              };
            }
            {
              "cAdvisor (box 1)" = {
                href = "http://${metricsHost "pi-node-a"}:8081/metrics";
                description = "Container metrics endpoint";
                server = "pi-node-a";
                container = "cadvisor";
              };
            }
            {
              "Promtail (box 1)" = {
                href = "http://${metricsHost "pi-node-a"}:9080/ready";
                description = "Log shipper readiness";
                server = "pi-node-a";
                container = "promtail";
              };
            }
            {
              "Traefik (box 1)" = {
                href = "http://${metricsHost "pi-node-a"}:8082/metrics";
                description = "Ingress metrics endpoint";
                server = "pi-node-a";
                container = "traefik";
              };
            }
            {
              "Pi-hole Exporter (box 1)" = {
                href = "http://${metricsHost "pi-node-a"}:9617/metrics";
                description = "Pi-hole exporter metrics";
                server = "pi-node-a";
                container = "pihole-exporter";
              };
            }
            {
              "Node Exporter (box 1)" = {
                href = "http://${metricsHost "pi-node-a"}:9100/metrics";
                description = "Host metrics endpoint";
                server = "pi-node-a";
              };
            }
            {
              "Docker Socket Proxy (box 1)" = {
                href = "http://pi-node-a.${config.lab.domain}:2375/_ping";
                description = "Read-only Docker API proxy";
                server = "pi-node-a";
                container = "docker-socket-proxy";
              };
            }
          ];
        }
        {
          "nas-host" = [
            {
              "KaraKeep" = {
                href = availabilityTargets.routed.karakeep;
                description = "Read-it-later and bookmarks";
                server = "nas-host";
                container = "karakeep";
              };
            }
            {
              "Gitea" = {
                href = availabilityTargets.routed.gitea;
                description = "Code forge (health in Uptime Kuma)";
                server = "nas-host";
                container = "gitea";
              };
            }
            {
              "ArchiveBox" = {
                href = availabilityTargets.routed.archivebox;
                description = "Web archive (health in Uptime Kuma)";
                server = "nas-host";
                container = "archivebox";
              };
            }
            {
              "Jellyfin" = {
                href = availabilityTargets.routed.jellyfin;
                description = "Media server";
                server = "nas-host";
                container = "nas-host-jellyfin";
              };
            }
            {
              "Outline" = {
                href = availabilityTargets.routed.outline;
                description = "Knowledge base";
                server = "nas-host";
                container = "outline";
              };
            }
            {
              "MySQL (shared)" = {
                href = "http://nas-host.${config.lab.domain}:3306";
                description = "Shared MySQL endpoint (TCP check in Kuma)";
                server = "nas-host";
                container = "nas-host-mysql";
              };
            }
            {
              "Postgres (shared)" = {
                href = "http://postgres.${config.lab.domain}:5433";
                description = "Shared DB endpoint (TCP check in Kuma)";
                server = "nas-host";
                container = "nas-host-postgres";
              };
            }
            {
              "Redis (shared)" = {
                href = "http://redis.${config.lab.domain}:6379";
                description = "Shared cache endpoint (TCP check in Kuma)";
                server = "nas-host";
                container = "nas-host-redis";
              };
            }
            {
              "Mongo (shared)" = {
                href = "http://mongo.${config.lab.domain}:27017";
                description = "Shared document DB endpoint (TCP check in Kuma)";
                server = "nas-host";
                container = "nas-host-mongo";
              };
            }
            {
              "Dolt (shared)" = {
                href = availabilityTargets.direct.doltMetrics;
                description = "Versioned SQL endpoint with Prometheus metrics";
                server = "nas-host";
                container = "nas-host-dolt";
              };
            }
            {
              "Docker Socket Proxy" = {
                href = "http://nas-host.${config.lab.domain}:2375/_ping";
                description = "Read-only Docker API proxy";
                server = "nas-host";
                container = "docker-socket-proxy";
              };
            }
            {
              "Paperless" = {
                href = availabilityTargets.routed.paperless;
                description = "Document inbox and archive";
                server = "nas-host";
                container = "nas-host-paperless";
              };
            }
            {
              "Tika" = {
                href = availabilityTargets.direct.tikaVersion;
                description = "Text extraction backend";
                server = "nas-host";
                container = "nas-host-tika";
              };
            }
            {
              "Gotenberg" = {
                href = availabilityTargets.direct.gotenbergHealth;
                description = "Document conversion backend";
                server = "nas-host";
                container = "nas-host-gotenberg";
              };
            }
          ];
        }
      ];
    };
  };

  # Homepage supports multiple Docker servers via docker.yaml.
  # Override the exact path read by the container mount.
  environment.etc."homepage/config/docker.yaml".text = lib.mkForce ''
    local:
      socket: /var/run/docker.sock
    pi-node-a:
      host: pi-node-a.${config.lab.domain}
      port: 2375
    pi-node-c:
      host: pi-node-c.${config.lab.domain}
      port: 2375
    nas-host:
      host: nas-host.${config.lab.domain}
      port: 2375
  '';

  # Keep unpoller in Prometheus-only mode; disable legacy InfluxDB writes.
  environment.etc."unpoller/docker-compose.yml".text = lib.mkForce ''
    services:
      unpoller:
        image: ${config.services.unpollerCompose.image.repository}:${config.services.unpollerCompose.image.tag}
        container_name: ${config.services.unpollerCompose.containerName}
        restart: unless-stopped

        env_file:
          - ${config.services.unpollerCompose.secretFile}

        environment:
          - UP_LISTEN=0.0.0.0:9130
          - UP_UNIFI_CONTROLLER_0_URL=${config.services.unpollerCompose.controller.url}
          - UP_UNIFI_CONTROLLER_0_VERIFY_SSL=${if config.services.unpollerCompose.controller.verifySsl then "true" else "false"}
          - UP_INFLUXDB_DISABLE=true
          - TZ

        ports:
          - "${config.services.unpollerCompose.listenAddress}:${toString config.services.unpollerCompose.listenPort}:9130"

        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "5"

        networks:
          - traefik

    networks:
      traefik:
        external: true
        name: ${config.services.unpollerCompose.network}
  '';

  # Pin mysql-exporter compose args so slave_status scraper stays disabled.
  environment.etc."mysql-exporter/docker-compose.yml".text = lib.mkForce ''
    services:
      mysql-exporter:
        image: ${config.services.mysqlExporterCompose.image.repository}:${config.services.mysqlExporterCompose.image.tag}
        container_name: ${config.services.mysqlExporterCompose.containerName}
        restart: unless-stopped

        environment:
          - TZ

        volumes:
          - /run/secrets/mysql-exporter.my.cnf:/etc/mysql-exporter.my.cnf:ro

        command:
          - --config.my-cnf=/etc/mysql-exporter.my.cnf
          - --mysqld.address=${config.services.mysqlExporterCompose.mysql.host}:${toString config.services.mysqlExporterCompose.mysql.port}
          - --no-collect.slave_status

        ports:
          - "${toString config.services.mysqlExporterCompose.listenPort}:9104"

        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "5"

        networks:
          - traefik

    networks:
      traefik:
        external: true
        name: ${config.services.mysqlExporterCompose.network}
  '';

  # Keep postgres-exporter collectors compatible with this Postgres role/version.
  environment.etc."postgres-exporter/docker-compose.yml".text = lib.mkForce ''
    services:
      postgres-exporter:
        image: ${config.services.postgresExporterCompose.image.repository}:${config.services.postgresExporterCompose.image.tag}
        container_name: ${config.services.postgresExporterCompose.containerName}
        restart: unless-stopped

        environment:
          - TZ

        env_file:
          - /run/secrets/postgres-exporter.env

        command:
          - --no-collector.wal
          - --no-collector.stat_bgwriter

        ports:
          - "${toString config.services.postgresExporterCompose.listenPort}:9187"

        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "5"

        networks:
          - traefik

    networks:
      traefik:
        external: true
        name: ${config.services.postgresExporterCompose.network}
  '';

  # Ghost auth-code emails use STARTTLS against the internal smtp-relay.
  # The relay presents a cert chain Ghost can't verify reliably, so allow it
  # for this internal hop to avoid login email failures (ESOCKET).
  environment.etc."ghost-blog/docker-compose.yml".text = lib.mkForce ''
    services:
      ghost:
        image: ${config.services.ghost.instances.blog.image.repository}:${config.services.ghost.instances.blog.image.tag}
        container_name: ${config.services.ghost.instances.blog.containerName}
        restart: unless-stopped
        init: true

        expose:
          - "2368"

        env_file:
          - /run/secrets/ghost-blog.env

        environment:
          - TZ=${config.services.ghost.instances.blog.timezone}
          - url=https://blog.${config.lab.domain}
          - NODE_ENV=production
          - NODE_EXTRA_CA_CERTS=/etc/ghost/homelab-root-ca.crt
          - database__client=mysql
          - database__connection__host=${config.services.ghost.instances.blog.database.host}
          - database__connection__port=${toString config.services.ghost.instances.blog.database.port}
          - database__connection__user=${config.services.ghost.instances.blog.database.user}
          - database__connection__database=${config.services.ghost.instances.blog.database.name}
          - mail__transport=SMTP
          - mail__from=${config.services.ghost.instances.blog.mail.from}
          - mail__options__host=${config.services.ghost.instances.blog.mail.host}
          - mail__options__port=${toString config.services.ghost.instances.blog.mail.port}
          - mail__options__secure=${if config.services.ghost.instances.blog.mail.secure then "true" else "false"}
          - mail__options__auth__user=${config.services.ghost.instances.blog.mail.user}
          - mail__options__tls__rejectUnauthorized=false

        volumes:
          - "${config.services.ghost.instances.blog.dataDir}:/var/lib/ghost/content"
          - "/etc/ssl/certs/homelab-root-ca.crt:/etc/ghost/homelab-root-ca.crt:ro"

        healthcheck:
          test:
            [
              "CMD",
              "node",
              "-e",
              "require('http').get('http://127.0.0.1:2368/', (r) => process.exit(r.statusCode < 500 ? 0 : 1)).on('error', () => process.exit(1));",
            ]
          interval: 15s
          timeout: 5s
          retries: 12
          start_period: 30s

        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "5"

        labels:
          - "traefik.enable=true"
          - "traefik.docker.network=${config.services.ghost.instances.blog.network}"
          - "traefik.http.routers.ghost-blog.rule=Host(`blog.${config.lab.domain}`)"
          - "traefik.http.services.ghost-blog.loadbalancer.server.port=2368"
          - "traefik.http.routers.ghost-blog.entrypoints=websecure"
          - "traefik.http.routers.ghost-blog.tls=true"

        networks:
          - traefik

    networks:
      traefik:
        external: true
        name: ${config.services.ghost.instances.blog.network}
  '';

  services.owntracksRecorder = {
    enable = true;
    hostname = "owntracks.${config.lab.domain}";
    dataDir = "/srv/owntracks";
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

  services.ghost.instances = {
    blog = {
      hostname = "blog.${config.lab.domain}";
      tls = true;
      dataDir = "/srv/ghost";

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

    # blog2 = {
    #   hostname = "blog2.${config.lab.domain}";
    #   tls = true;
    #   dataDir = "/var/lib/ghost-blog2";
    #   database = {
    #     host = "nas-host.${config.lab.domain}";
    #     port = 3306;
    #     name = "ghost_blog2";
    #     user = "ghost_blog2";
    #     passwordFile = "/run/secrets/ghost-blog2-db-password";
    #   };
    #   mail = {
    #     enable = true;
    #     from = "eduardoshanahan@gmail.com";
    #     host = "smtp-relay.${config.lab.domain}";
    #     port = 2525;
    #     secure = false;
    #     user = "";
    #     passwordFile = config.sops.secrets.ghost-mail-password.path;
    #   };
    # };
  };

  services.grafanaCompose = {
    enable = true;
    hostname = "grafana.${config.lab.domain}";
    dataDir = "/srv/grafana";
    adminPasswordFile = config.sops.secrets.grafana-admin-password.path;
    database = {
      type = "postgres";
      postgres = {
        host = "postgres.${config.lab.domain}";
        port = 5433;
        name = "grafana";
        user = "grafana";
        passwordFile = config.sops.secrets.grafana-db-password.path;
        sslMode = "disable";
      };
    };
    auth.genericOauth = {
      enable = true;
      clientIdFile = config.sops.secrets.grafana-oidc-client-id.path;
      clientSecretFile = config.sops.secrets.grafana-oidc-client-secret.path;
      authUrl = "https://authentik.${config.lab.domain}/application/o/authorize/";
      tokenUrl = "https://authentik.${config.lab.domain}/application/o/token/";
      apiUrl = "https://authentik.${config.lab.domain}/application/o/userinfo/";
      scopes = "openid profile email";
      usePkce = true;
      tlsSkipVerifyInsecure = true;
    };
    tls = true;
    provisioning.datasources.loki.url = "http://loki.${config.lab.domain}:3100";
    backup = {
      enable = true;
      targetDir = "/srv/grafana-backups";
      schedule = "daily";
      keepDays = 14;
    };
  };

  services.alertmanager = {
    enable = true;
    hostname = "alertmanager.${config.lab.domain}";
    tls = true;
    dataDir = "/srv/alertmanager";

    notifications = {
      email = {
        enable = true;
        smarthost = if hasSmtpRelayModule then "smtp-relay.${config.lab.domain}:2525" else "smtp.gmail.com:587";
        requireTls = !hasSmtpRelayModule;
        from = "noreply@internal.example";
        to = "contact@primary.example";
        authUsername = "eduardoshanahan@gmail.com";
        authPasswordFile = config.sops.secrets.alertmanager-smtp-password.path;
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
    dataDir = "/srv/prometheus";
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
      authentikTargets = [
        "authentik-server:9300"
      ];
      vikunjaTargets = [
        "vikunja:3456"
      ];
      unpollerTargets = monitoringTargets.unpoller;
      doltTargets = monitoringTargets.dolt;
    };

    tls = true;
  };

  services.promtailCompose = {
    enable = true;
    dataDir = "/srv/promtail";
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
    9187
  ] ++ lib.optionals enableRedisExporter [
    9121
  ] ++ lib.optionals enableMysqlExporter [
    9104
  ] ++ lib.optionals hasMongoExporterModule [
    9216
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
}) (lib.recursiveUpdate
  (lib.recursiveUpdate
    (lib.recursiveUpdate
      (lib.optionalAttrs hasSmtpRelayModule {
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
          passwordFile = config.sops.secrets.smtp-relay-upstream-password.path;
        };

        allowedSenderDomains = [
          config.lab.domain
          "primary.example"
          "gmail.com"
        ];
      };

      systemd.services.smtp-relay-backup = {
        description = "Backup SMTP relay runtime volumes";
        serviceConfig = {
          Type = "oneshot";
        };
        path = with pkgs; [ coreutils docker gnutar gzip ];
        script = ''
          set -euo pipefail

          backup_root="/srv/backups/smtp-relay"
          ts="$(date -u +%Y%m%dT%H%M%SZ)"
          out_dir="''${backup_root}/''${ts}"

          mkdir -p "$out_dir"

          if [ ! -f /etc/smtp-relay/docker-compose.yml ]; then
            echo "smtp-relay backup: missing /etc/smtp-relay/docker-compose.yml" >&2
            exit 1
          fi

          cp /etc/smtp-relay/docker-compose.yml "$out_dir/docker-compose.yml"

          backup_mount() {
            local destination="$1"
            local archive_name="$2"
            local volume_name mountpoint

            volume_name="$(docker inspect smtp-relay --format "{{range .Mounts}}{{if eq .Destination \"''${destination}\"}}{{.Name}}{{end}}{{end}}")"
            if [ -z "$volume_name" ]; then
              echo "smtp-relay backup: no docker volume mapped at ''${destination}" >&2
              return 1
            fi

            mountpoint="$(docker volume inspect "$volume_name" --format '{{.Mountpoint}}')"
            tar -C "$mountpoint" -czf "$out_dir/''${archive_name}" .
          }

          backup_mount "/etc/postfix" "etc-postfix.tar.gz"
          backup_mount "/var/spool/postfix" "var-spool-postfix.tar.gz"
          backup_mount "/etc/opendkim/keys" "etc-opendkim-keys.tar.gz"

          (
            cd "$out_dir"
            sha256sum docker-compose.yml *.tar.gz > SHA256SUMS
          )

          # Keep roughly 30 days of backups.
          find "$backup_root" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
        '';
      };

      systemd.timers.smtp-relay-backup = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "20m";
          Persistent = true;
        };
      };
      })
      (lib.optionalAttrs hasD2Module {
        services.d2Compose = {
          enable = true;
          hostname = "d2.${config.lab.domain}";
          tls = true;
          dataDir = "/srv/d2";
          auth.username = "eduardo";
        };
      }))
    (lib.optionalAttrs hasPostgresExporterModule {
      services.postgresExporterCompose = {
        enable = true;
        listenPort = 9187;
        dataSourceNameFile = config.sops.secrets.homeassistant-recorder-db-url.path;
      };

      services.prometheusCompose.scrape.postgresExporterTargets = monitoringTargets.postgresExporter;
    }))
  (lib.recursiveUpdate
    (lib.recursiveUpdate
      (lib.optionalAttrs (hasRedisExporterModule && enableRedisExporter) {
        services.redisExporterCompose = {
          enable = true;
          listenPort = 9121;
          redis = {
            username = "redis-admin";
            host = "redis.${config.lab.domain}";
            port = 6379;
            passwordFile = config.sops.secrets.redis-password.path;
          };
        };

        services.prometheusCompose.scrape.redisExporterTargets = monitoringTargets.redisExporter;
      })
      (lib.optionalAttrs (hasMysqlExporterModule && enableMysqlExporter) {
        services.mysqlExporterCompose = {
          enable = true;
          listenPort = 9104;
          mysql = {
            host = "nas-host.${config.lab.domain}";
            port = 3306;
            username = "ghost";
            passwordFile = config.sops.secrets.ghost-db-password.path;
          };
        };

        services.prometheusCompose.scrape.mysqlExporterTargets = monitoringTargets.mysqlExporter;
      }))
    (lib.optionalAttrs hasMongoExporterModule {
      services.mongodbExporterCompose = {
        enable = true;
        listenPort = 9216;
        mongoUriFile = config.sops.secrets.mongodb-exporter-uri.path;
      };

      services.prometheusCompose.scrape.mongodbExporterTargets = monitoringTargets.mongodbExporter;
    })))
