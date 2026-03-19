# Root Session Docs Archive Summary (2026-03-18)

This document preserves the still-relevant outcomes from the old root-level
session and planning files that used to live at the top of the shared
workspace.

Those files were useful as working notes during implementation, but they had
become stale, duplicated current docs, and lived outside the owning repos. The
root-level copies were removed after this summary was written.

## Enduring Cross-Repo Outcomes

### `pi-node-b` media stack

- The media request and management stack now lives on `pi-node-b` with a
  FQDN-first shape:
  - `seerr`
  - `radarr`
  - `sonarr`
  - `lidarr`
  - `prowlarr`
  - `lazylibrarian`
- qBittorrent and Jellyfin remain owned by `synology-services` on `nas-host`.
- Media application state on `pi-node-b` lives under `/srv/<service>`.
- Cross-host integrations should prefer stable FQDNs instead of IPs or
  container-only names.
- Current operational truth is now split across:
  - `nix-services/services/{seerr,radarr,sonarr,lidarr,prowlarr,lazylibrarian}/README.md`
  - `nix-pi/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - `synology-services/nas-host/{jellyfin,qbittorrent}/README.md`

### Storage and runtime layout

- The old `/srv/prometheus/...` path sprawl on `pi-node-b` is no longer the
  intended model.
- The current storage rule is: persistent app state belongs under `/srv`, with
  `/srv/<service>` preferred for new or migrated services.
- Canonical docs:
  - `nix-pi/README.md`
  - `nix-pi/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - `nix-pi/docs/plans/STORAGE_DIRECTORY_AUDIT_AND_REMEDIATION_PLAN.md`

### Shared infra migrations and app follow-through

- Shared PostgreSQL on `nas-host`, SMTP relay on `pi-node-b`, Outline shared
  infra usage, Home Assistant, Grafana, and Alertmanager email were all
  implemented and are no longer “next session” plans.
- Canonical current-state docs:
  - `nix-pi/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - `nix-services/services/{smtp-relay,home-assistant,grafana,alertmanager}/README.md`
  - `synology-services/nas-host/{postgres,outline}/README.md`

### Service investigation follow-up

- The detailed root-level investigation notes were superseded by the committed
  continuation and the documentation sync work completed afterward.
- Canonical docs:
  - `nix-services/SERVICE_INVESTIGATION_CONTINUATION_2026-03-18.md`
  - `nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
  - `nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
  - `nix-services/DOC_SYNC_CHECKLIST.md`

### Woodpecker deployment shape

- The intended and implemented shape is:
  - Woodpecker server on `pi-node-b`
  - ARM64 agent on `pi-node-b`
  - separate AMD64 NAS agent from `synology-services/nas-host/woodpecker-agent`
  - shared PostgreSQL on `nas-host`
  - Gitea on `nas-host`
- Canonical docs:
  - `nix-services/services/woodpecker/README.md`
  - `synology-services/nas-host/woodpecker-agent/README.md`
  - `nix-pi/nixos/hosts/private/pi-node-b.nix`

## Removed Root Files And Their Replacements

### Media planning and implementation briefs

- Removed:
  - `declarative_media_bootstrap_handoff_2026-03-15.md`
  - `declarative_media_bootstrap_plan_2026-03-14.md`
  - `seerr_rpi_box_02_postgres_implementation_brief_2026-03-11.md`
  - `radarr_rpi_box_02_implementation_brief_2026-03-11.md`
  - `prowlarr_rpi_box_02_implementation_brief_2026-03-11.md`
  - `sonarr_rpi_box_02_implementation_brief_2026-03-13.md`
  - `lidarr_rpi_box_02_implementation_brief_2026-03-13.md`
  - `service_fqdn_migration_plan_2026-03-14.md`
- Replaced by:
  - service READMEs in `nix-services/services/*`
  - host runtime and validation notes in
    `nix-pi/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - live host wiring in `nix-pi/nixos/hosts/private/pi-node-b.nix`

### Grafana handoffs and next-session prompts

- Removed:
  - `grafana_dashboard_review_handover_2026-03-07.md`
  - `grafana_next_session_prompt_2026-03-07.md`
  - `grafana_next_session_prompt_2026-03-08_pre_compaction.md`
- Replaced by:
  - `nix-services/services/grafana/README.md`
  - current host/operator notes in
    `nix-pi/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`

### Migration and session handoffs from early March

- Removed:
  - `postgres_services_handover_2026-03-05.md`
  - `services_migration_handover_2026-03-05.md`
  - `session_handover_2026-03-05.md`
  - `session_handover_2026-03-05_alertmanager_and_outline.md`
  - `session_handover_2026-03-05_home_assistant.md`
  - `session_handover_2026-03-08_box2_data_dir_migration.md`
- Replaced by:
  - `nix-pi/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
  - `synology-services/nas-host/DOCUMENTATION_INDEX.md`
  - service READMEs in `nix-services/services/*`

### Service investigation handoff

- Removed:
  - `service_investigation_followups_2026-03-17.md`
- Replaced by:
  - `nix-services/SERVICE_INVESTIGATION_CONTINUATION_2026-03-18.md`

### Woodpecker planning notes

- Removed:
  - `woodpecker_ci_homelab_plan_2026-03-10.md`
  - `woodpecker_ci_rollout_checklist_2026-03-11.md`
- Replaced by:
  - `nix-services/services/woodpecker/README.md`
  - `synology-services/nas-host/woodpecker-agent/README.md`
  - host wiring in `nix-pi/nixos/hosts/private/pi-node-b.nix`

## Future Placement Rule

- Do not create new long-lived session or follow-up docs at the shared
  workspace root.
- Put continuity docs in the owning repo:
  - `nix-pi/docs/` for host lifecycle, host runtime, and operator continuity
  - `nix-services/` for shared service investigations and architecture notes
  - `synology-services/nas-host/` for Synology host runbooks and continuity
