# ADR-0002: Fleet operations documentation

## Status

Accepted

## Context

We need a durable record of:

- What decisions were made (and why)
- What operational actions were taken on the fleet (and how to repeat them)

This must be understandable by another group following the same process.

## Decision

We will document fleet work using three complementary artifacts:

1) **ADRs** (`documentation/adr/`)
   - Record significant decisions that affect how the fleet is built, deployed, or operated.

2) **Runbooks** (`documentation/runbooks/`)
   - Step-by-step procedures to perform operational tasks (bootstrap, deploy, recovery).
   - Written to be executable by someone new to the project.

3) **Diary entries** (`documentation/diary/yyyy-mm-dd.md`)
   - A chronological record of significant changes and what was actually done.
   - Each entry must include which boxes were affected and how the change was verified.

## Diary entry template

Every significant change entry should include:

- **Summary**: 1–3 bullets of what changed
- **Boxes affected**: `rpi-box-01`, `rpi-box-02`, `rpi-box-03`, …
- **Commands**: key commands run (deploy/pull-hardware/etc.)
- **Verification**: what you checked (SSH, `nixos-version`, services, etc.)
- **Notes/Rollback**: anything to watch out for

## Consequences

- Slight overhead to write down actions.
- Much easier handoff, troubleshooting, and reproducibility across teams.

