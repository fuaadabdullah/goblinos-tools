---
description: "README"
---

# Goblin Quick TUI (Textual)

Lightweight terminal UI to run quick repo maintainer commands (queue status, doctor checks, kill zombies). Built with Textual + Rich.

Files
- `goblin_tui.py` — the TUI application
- `config.json.example` — example command mappings (copy to `config.json` to customize)
- `requirements.txt` — Python packages needed

Quick start

1. Create a Python venv and install requirements (macOS / zsh):

```bash
python3 -m venv .venv-tui
source .venv-tui/bin/activate
pip install -r tools/tui/requirements.txt
```

2. Copy the example config and edit commands if needed:

```bash
cp tools/tui/config.json.example tools/tui/config.json
# Edit tools/tui/config.json to adjust the shell commands for your environment
```

3. Run the TUI:

```bash
python tools/tui/goblin_tui.py --config tools/tui/config.json
```

Notes
- The TUI runs commands using `/bin/bash -lc` in the configured working directory.
- Commands should be safe, idempotent, and non-interactive. The default `goblin kill-zombies` maps to the repo `tools/scripts/kill-port.sh 8000` helper.
- If you prefer a Node alternative (Ink), I can add that next.

Customization
- `config.json` supports a top-level `commands` object mapping label -> shell command, and `cwd` which may include `${repo_root}`.
