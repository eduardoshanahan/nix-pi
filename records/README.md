# Project Records

Purpose: Long-term, append-only-ish records of decisions, work, and session state
to support pausing and resuming across sessions without re-asking questions.

Guidelines

- Prefer appending new entries over editing old ones.
- If a previous decision changes, record a new decision and cross-reference the
  old one.
- Keep entries brief but precise; link to relevant files/paths when possible.
- Review ADRs regularly for conflicts and supersede when needed.

Files

- DECISIONS.md: Timestamped decisions with context, rationale, and status.
- WORKLOG.md: What was done, when, and why.
- architecture-decisions/: One file per architecture decision (ADRs).
