---
description: "README"
---

# LaunchAgents integration for headless backend

This small helper provides a macOS `launchd` plist and simple install/uninstall scripts so you can run the backend as a persistent user service (survives GUI app quits).

Files added
- `com.forge.goblinos.backend.plist` — the launchd plist (under this folder). Edit the ProgramArguments line if your paths differ.
- `install_launchd.sh` — copy the plist to `~/Library/LaunchAgents` and `launchctl load` it.
- `uninstall_launchd.sh` — unload and remove the plist.

Default values used
- Working directory: `/Users/fuaadabdullah/ForgeMonorepo/ForgeTM`
- Python venv activation: `/Users/fuaadabdullah/.venvs/forge-terminal/bin/activate`
- Command started: `uvicorn forge.main:app --host 127.0.0.1 --port 8000`
- Logs: `/tmp/goblinos.out.log` and `/tmp/goblinos.err.log`

Before you install
- Confirm the working directory and the venv path in `com.forge.goblinos.backend.plist`.
- If you prefer the `apps/backend/.venv` in the repo, replace the activate path and working directory accordingly.

Install
1. Make the scripts executable if needed:

```bash
chmod +x tools/launchd/install_launchd.sh tools/launchd/uninstall_launchd.sh
```

2. Run the installer:

```bash
./tools/launchd/install_launchd.sh
```

Validate
- Check the service is loaded:

```bash
launchctl list | grep com.forge.goblinos.backend
```

- Tail logs:

```bash
tail -F /tmp/goblinos.out.log /tmp/goblinos.err.log
```

Uninstall

```bash
./tools/launchd/uninstall_launchd.sh
```

Notes and caveats
- New macOS versions may prefer `launchctl bootstrap` instead of `load`/`unload`. The install script uses `load`/`unload` for compatibility; if you run into issues, replace with `launchctl bootstrap gui/$UID \"$PLIST_DEST\"` and `launchctl bootout gui/$UID \"$PLIST_DEST\"`.
- `launchd` runs services in a minimal environment. Explicitly source your venv and use absolute paths (as the plist currently does).
- Do not commit secrets into the plist. Use environment files or system-level secrets as needed; `launchd` will not read `.env` files for you unless you source them in the command.
