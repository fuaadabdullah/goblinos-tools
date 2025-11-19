---
description: "README"
---

Secrets scanning utilities for ForgeMonorepo

Overview
--------

This folder contains tooling to run secrets checks locally and in CI. It is owned by the Keepers & Huntress guilds; Magnolia Nightbloom is the triage owner.

Quick commands
--------------

- Fast staged check (used by `lefthook`):

  bash tools/secrets/secrets_scan.sh --staged

- Full local scan (may be slow):

  bash tools/secrets/secrets_scan.sh --full

- CI mode (used by GitHub Actions):

  bash tools/secrets/secrets_scan.sh --ci

Outputs
-------

Artifacts are written to `artifacts/secrets/` and SARIF files to `artifacts/sarif/`.

Baselines
---------

Add or refresh baselines with:

  detect-secrets scan > tools/secrets/detect-secrets-baseline.json

Review baseline changes carefully and have Magnolia + Sentenial sign-off before committing.

Tips
----
- Install developer prerequisites for best local experience: `pip install detect-secrets trufflehog` and `brew install gitleaks` (macOS).
- CI installs tools as part of the workflow; local installs are recommended for fast feedback.
