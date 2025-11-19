#!/usr/bin/env bash
set -euo pipefail

# Uninstall the com.forge.goblinos.backend launchd job
# Usage: ./uninstall_launchd.sh

PLIST_DEST="$HOME/Library/LaunchAgents/com.forge.goblinos.backend.plist"

if [[ -f "$PLIST_DEST" ]]; then
  echo "Unloading job..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
  echo "Removing plist: $PLIST_DEST"
  rm -f "$PLIST_DEST"
  echo "Uninstalled."
else
  echo "No plist found at $PLIST_DEST"
fi
