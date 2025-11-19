---
description: "README"
---

# Goblin Node TUI

Simple Node-based TUI for quick repository maintainer commands.

Install dependencies in the tool folder and run:

```bash
pnpm -C tools/tui-node install
pnpm -C tools/tui-node start
```

By default the tool reads `tools/tui/config.json` (or `tools/tui/config.json.example`).
For non-interactive tests you can set `GOBLIN_CMD=1` to pick the first command.
