# Risks

Format

- Date: YYYY-MM-DD
- Risk: short statement
- Impact: low/medium/high
- Likelihood: low/medium/high
- Mitigation: brief plan
- Status: open/mitigated

---

- Date: 2026-01-20
- Risk: Confidential information accidentally committed to Git.
- Impact: high
- Likelihood: medium
- Mitigation: Use `.gitignore`, local-only config, and a clear confidentiality
  guide; review artifacts before publish.
- Status: open

- Date: 2026-01-20
- Risk: Onboarding friction if flakes are misconfigured or Nix is not installed.
- Impact: medium
- Likelihood: medium
- Mitigation: Provide clear setup docs and keep dev shell minimal.
- Status: open

- Date: 2026-01-20
- Risk: Cross-architecture SD image builds may fail without emulation support.
- Impact: medium
- Likelihood: medium
- Mitigation: Document binfmt requirements and keep builds simple.
- Status: open
