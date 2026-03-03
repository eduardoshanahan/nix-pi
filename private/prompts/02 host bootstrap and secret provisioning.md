# Codex Initial Prompt — nix-pi

## Host Bootstrap & Secret Provisioning

You are working in the repository **`nix-pi`**.

This repository owns **host-level concerns only**:
hardware, base OS, users, SSH, networking, Docker enablement,
and **secret provisioning**.

This repository does **not** define application services.

---

## AUTHORITATIVE CONSTRAINTS (NON-NEGOTIABLE)

- This repository **must not** define application logic.
- This repository **must not** contain plaintext secrets.
- This repository **may** contain encrypted secrets.
- All hosts are **aarch64-linux (ARM64)**.
- Secrets must be provisioned at **activation time**, not build time.
- Secrets must be written to **`/run/secrets` (tmpfs)**.
- Nothing secret may ever enter the Nix store.
- Rebooting a host **must require secrets to be re-decrypted**.

If any instruction conflicts with these rules, STOP and ask.

---

## CURRENT STATE (AUTHORITATIVE)

- Hosts import services from `nix-services`.
- Services expect secrets to exist at fixed paths
  (e.g. `/run/secrets/*.env`).
- Secret persistence strategy is **runtime-only**.
- No Vault or external secret store is in use.
- Manual secret injection is no longer acceptable.

---

## TASK OBJECTIVE

Implement **sops-nix** to provide secrets to hosts in a
fully declarative, reboot-safe, git-safe way.

---

## REQUIRED OUTCOMES

You MUST:

1. Integrate **sops-nix** into `nix-pi`.
2. Configure **age-based decryption** using a per-host private key located at:

/var/lib/sops/age.key

1. Assume:

- The private key already exists on the host
- The public key is safe to commit

1. Define one or more encrypted secrets files (YAML).
2. Declare secrets that are:

- Decrypted at activation time
- Written to `/run/secrets`
- Owned by `root`
- Mode `0400`

1. Support `dotenv`-style secrets for Docker containers.
2. Make **no assumptions** about which services consume the secrets.

---

## EXPLICIT NON-GOALS

You must NOT:

- Modify any service implementation
- Reference docker-compose files
- Add application-specific logic
- Introduce Vault or external secret stores
- Persist secrets to disk
- Add manual provisioning steps

---

## WORKING MODE

- Prefer explicit configuration over clever abstractions.
- Make the smallest change that satisfies the objective.
- Treat failures loudly and early.
- Document assumptions inline where necessary.

---

## END CONDITION

Stop once:

- sops-nix is correctly integrated
- Secrets appear in `/run/secrets` after activation
- No service-specific logic is introduced
