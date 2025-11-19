#!/usr/bin/env bash
set -euo pipefail

# Simple helper to inspect and clean VS Code local caches and storage.
# It is intentionally conservative: by default it only reports sizes.

WORKSPACE_STORAGE="$HOME/Library/Application Support/Code/User/workspaceStorage"
GLOBAL_STORAGE="$HOME/Library/Application Support/Code/User/globalStorage"
EXTENSIONS_DIR="$HOME/.vscode/extensions"

usage() {
  cat <<EOF
Usage: $0 [--size | --archive <dir> | --remove]
  --size             Show sizes for VS Code workspace storage, global storage and extensions directory.
  --archive <dir>    Archive above paths to <dir> and remove originals (safety: requires writable path).
  --remove           Remove workspace and global storage directories (destructive; confirm with --yes).
  --yes              Skip interactive confirmation for destructive actions.
EOF
}

if [[ ${#@} -eq 0 ]]; then
  usage
  exit 0
fi

ACTION="$1"
shift || true

confirm() {
  if [[ "${CONFIRM:-}" == "--yes" || "${CONFIRM:-}" == "--YES" ]]; then
    return 0
  fi
  read -r -p "Are you sure? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

size_show() {
  echo "Sizes:"
  du -sh "$WORKSPACE_STORAGE" 2>/dev/null || echo " workspaceStorage: missing"
  du -sh "$GLOBAL_STORAGE" 2>/dev/null || echo " globalStorage: missing"
  du -sh "$EXTENSIONS_DIR" 2>/dev/null || echo " extensions: missing"
}

case "$ACTION" in
  --size)
    size_show
    ;;
  --archive)
    DEST="$1"
    mkdir -p "$DEST"
    for p in "$WORKSPACE_STORAGE" "$GLOBAL_STORAGE" "$EXTENSIONS_DIR"; do
      if [[ -e "$p" ]]; then
        name=$(basename "$p")
        archive_name="$DEST/vscode_${name}_$(date +%Y%m%d_%H%M%S).tgz"
        echo "Archiving $p -> $archive_name"
        tar --no-mac-metadata -czf "$archive_name" -C "$(dirname "$p")" "$name"
        echo "Removing original: $p"
        rm -rf "$p"
      else
        echo "Skip missing: $p"
      fi
    done
    ;;
  --remove)
    CONFIRM=${1:-}
    echo "This will permanently delete your VS Code workspace and global storage."
    if confirm; then
      rm -rf "$WORKSPACE_STORAGE" "$GLOBAL_STORAGE"
      echo "Deleted."
    else
      echo "Aborted."
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac

exit 0
