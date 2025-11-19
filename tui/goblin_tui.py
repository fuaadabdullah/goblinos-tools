#!/usr/bin/env python3
"""Goblin quick TUI — small Textual app to run configurable repo commands.

Usage:
  python goblin_tui.py [--config /path/to/config.json]

It reads a JSON config with a `commands` map (label -> shell command) and runs the
selected command, streaming stdout/stderr to the output panel.

The example config is at `tools/tui/config.json.example`.
"""
from __future__ import annotations

import argparse
import asyncio
#!/usr/bin/env python3
"""Goblin quick TUI — small Textual app to run configurable repo commands.

Usage:
  python goblin_tui.py [--config /path/to/config.json]

It reads a JSON config with a `commands` map (label -> shell command) and runs the
selected command, streaming stdout/stderr to the output panel.

The example config is at `tools/tui/config.json.example`.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
from typing import Dict

from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Header, Footer, Static, TextLog


DEFAULT_CONFIG = Path(__file__).parent / "config.json.example"


def load_config(path: Path) -> Dict[str, str]:
    try:
        raw = json.loads(path.read_text())
        cmds = raw.get("commands", {})
        if not isinstance(cmds, dict):
            raise ValueError("commands must be a map of label->command")
        return cmds
    except Exception as e:
        raise RuntimeError(f"Failed to load config {path}: {e}")


class OutputPanel(Static):
    pass


class GoblinTUI(App):
    CSS_PATH = None
    BINDINGS = [("q", "quit", "Quit")]

    def __init__(self, commands: Dict[str, str], cwd: str | None = None) -> None:
        super().__init__()
        self.commands = commands
        self.cwd = cwd or os.getcwd()
        self.process_task: asyncio.Task | None = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical(id="left", classes="panel"):
                yield Static("Goblin Quick Commands", id="title")
                for label in sorted(self.commands.keys()):
                    yield Button(label, id=f"btn:{label}")
            with Vertical(id="right", classes="panel"):
                yield TextLog(highlight=True, markup=True, id="log")
        yield Footer()

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        label = event.button.label
        cmd = self.commands.get(label)
        if not cmd:
            await self.log(f"Unknown command: {label}")
            return
        log = self.query_one(TextLog)
        log.clear()
        await self.run_shell(cmd, log)

    async def log(self, message: str) -> None:
        log = self.query_one(TextLog)
        log.write(message)

    async def run_shell(self, cmd: str, log: TextLog) -> None:
        """Run the shell command asynchronously and stream output to the TextLog."""
        await self.log(f"[bold green]Running:[/bold green] {cmd}\nWorking dir: {self.cwd}\n")
        # Use /bin/bash -lc so user shell features/rc works; keep it simple and cross-machine
        popen = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=self.cwd,
            executable="/bin/bash",
        )

        assert popen.stdout is not None

        try:
            while True:
                line = await popen.stdout.readline()
                if not line:
                    break
                text = line.decode(errors="replace").rstrip()
                log.write(text)
            rc = await popen.wait()
            log.write(f"\n[bold]{cmd} exited with code {rc}[/bold]")
        except asyncio.CancelledError:
            popen.kill()
            await popen.wait()
            log.write("\n[red]Command cancelled[/red]")


def resolve_repo_root() -> str:
    # repo root is three directories up from tools/tui by default for this workspace layout
    p = Path(__file__).resolve()
    repo = p.parents[3] if len(p.parents) >= 4 else Path.cwd()
    return str(repo)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        "-c",
        type=Path,
        default=DEFAULT_CONFIG,
        help="Path to JSON config file (label -> shell command)",
    )
    parser.add_argument("--cwd", help="Working directory for commands (use ${repo_root} in config)")
    args = parser.parse_args()

    cfg_path: Path = args.config
    if not cfg_path.exists():
        print(f"Config not found: {cfg_path}. Copy tools/tui/config.json.example to tools/tui/config.json and edit.")
        return 2

    raw = json.loads(cfg_path.read_text())
    commands = raw.get("commands", {})
    cwd = args.cwd or raw.get("cwd")
    if cwd and "${repo_root}" in cwd:
        cwd = cwd.replace("${repo_root}", resolve_repo_root())
    if not cwd:
        cwd = resolve_repo_root()

    app = GoblinTUI(commands=commands, cwd=cwd)
    app.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
