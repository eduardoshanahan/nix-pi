# Uptime Kuma + Authentik Limitation (2026-03-06)

## Summary

Attempted to integrate Uptime Kuma with Authentik as a native login provider.
Current deployed Kuma version (`2.1.3`) does not expose native OIDC/OAuth login
for user authentication.

## What Was Verified

- Running container: `uptime-kuma 2.1.3`.
- Server auth implementation is local user/password based (`server/auth.js`).
- OAuth/OIDC references found in code are for monitor target auth
  (`oauth2-cc`), not web-user SSO login.
- `uptime_kuma.setting` table on MariaDB has no OIDC/SSO login keys.

## Decision

- Do not attempt native Authentik OIDC login for Kuma on `2.1.3`.
- Keep Kuma local auth for now.
- Move SSO effort to apps with supported OIDC implementations (Grafana,
  Vikunja, Gitea).

## Revisit Trigger

Re-check when upgrading Kuma to a version that explicitly documents native SSO
for user login.

## Optional Workaround

If needed, enforce SSO at proxy layer with Authentik forward-auth outpost, while
keeping Kuma local auth internally.
