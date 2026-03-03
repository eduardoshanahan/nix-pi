# nix-pi Deployment Prompt

You are working in the `nix-pi` repository.

Services are defined externally in the `nix-services` repository.
This repository is responsible only for:

- Host definitions
- Hardware configuration
- Selecting which services run on which host

Before making any changes:

1. Read and obey the Service Deployment Model from `nix-services`.
2. Treat service modules from `nix-services` as black boxes.

Task:
Enable services from `nix-services` on the selected hosts
according to the Service Deployment Model.

Rules:

- Do not modify service internals.
- Do not duplicate service logic.
- Do not introduce host-specific service behavior.
- Changes must affect one host at a time.
