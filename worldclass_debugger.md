---
description: "worldclass_debugger"
---

# WorldClass Debugger

This is a lightweight developer helper assigned to Forge/Huntress/Mages guilds for quick triage.

## Purpose

- Run common triage flows from one small script.
- Intended for local development and CI debug steps.

## Usage

```bash
# lint/type checks
bash tools/worldclass_debugger.sh audit

# run smoke probes (if available)
bash tools/worldclass_debugger.sh probe

# query backend jobs endpoint (local server expected at 127.0.0.1:8000)
bash tools/worldclass_debugger.sh jobs
```

## Assigned goblins

- Dregg Embercode (Forge)
- Magnolia Nightbloom (Huntress)
- Launcey Gauge (Mages)

## Notes

- The script is deliberately small and safe — it delegates to existing repo scripts (`tools/lint_all.sh`, `tools/smoke.sh`) or performs simple HTTP check.
- It does not modify repo state beyond running read-only checks and non-destructive probes.
