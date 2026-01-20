# Project Records

Purpose: Long-term, append-only-ish records of decisions, work, and session state
to support pausing and resuming across sessions without re-asking questions.

Guidelines

- Prefer appending new entries over editing old ones.
- If a previous decision changes, record a new decision and cross-reference the
  old one.
- Keep entries brief but precise; link to relevant files/paths when possible.
- Update SESSION_PROMPT.md whenever a session ends or a major milestone occurs.
- Review ADRs regularly for conflicts and supersede when needed.

Files

- DECISIONS.md: Timestamped decisions with context, rationale, and status.
- WORKLOG.md: What was done, when, and why.
- SESSION_PROMPT.md: Current project state and a ready-to-use prompt for
  resuming.
- QUESTIONS.md: Open questions and pending clarifications.
- RISKS.md: Tracked project risks with mitigation and status.
- MILESTONES.md: Project milestones and status.
- CHANGELOG.md: Dated record of notable changes.
- architecture-decisions/: One file per architecture decision (ADRs).
