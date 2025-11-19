#!/usr/bin/env bash
set -euo pipefail

# Install the launchd plist to the current user's LaunchAgents and load it.
# Usage: ./install_launchd.sh

PLIST_SRC="$(cd "$(dirname "$0")" && pwd)/com.forge.goblinos.backend.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.forge.goblinos.backend.plist"

echo "Source plist: $PLIST_SRC"
echo "Destination:   $PLIST_DEST"

if [[ ! -f "$PLIST_SRC" ]]; then
  echo "ERROR: source plist not found: $PLIST_SRC" >&2
  exit 2
fi

mkdir -p "$HOME/Library/LaunchAgents"

echo "Copying plist to LaunchAgents..."
cp -f "$PLIST_SRC" "$PLIST_DEST"

echo "Unloading previous job (if any)..."
launchctl unload "$PLIST_DEST" 2>/dev/null || true

echo "Loading job..."
launchctl load -w "$PLIST_DEST"

echo "Done. To see logs check: /tmp/goblinos.out.log and /tmp/goblinos.err.log"
echo "To view job status: launchctl list | grep com.forge.goblinos.backend"
