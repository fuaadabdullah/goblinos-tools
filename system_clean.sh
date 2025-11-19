#!/usr/bin/env bash
set -euo pipefail

# System-level safe cleanup for macOS user cache and dev caches
# - Archives select VS Code storage to external drive
# - Clears macOS and dev caches: Library/Caches, ~/.cache, ~/.npm, ~/.pnpm-store

EXT_VOL_DEFAULT="/Volumes/Fuaad"
BACKUP_DIR_NAME="System-Clean-Backups"
TS="$(date +%Y-%m-%d_%H-%M-%S)"

EXT_VOL="${1:-$EXT_VOL_DEFAULT}"
if [[ ! -d "$EXT_VOL" ]]; then
  echo "ERROR: External volume not found: $EXT_VOL"
  exit 1
fi

backup_root="$EXT_VOL/$BACKUP_DIR_NAME"
backup_path="$backup_root/$TS"
mkdir -p "$backup_path"

HOME_DIR="$HOME"
echo "Home: $HOME_DIR"
echo "Backup destination: $backup_path"

archive_path() {
  local src="$1"
  local name="$2"
  if [[ -e "$src" ]]; then
    echo "Archiving $src -> $backup_path/$name.tgz"
    COPYFILE_DISABLE=1 tar --no-mac-metadata -czf "$backup_path/$name.tgz" -C "/" "${src#/}"
    if [[ -s "$backup_path/$name.tgz" ]]; then
      echo "Archive OK: $name.tgz ($(du -h "$backup_path/$name.tgz" | awk '{print $1}'))"
      echo "Removing original: $src"
      rm -rf "$src"
    else
      echo "ERROR: Failed to archive $src"
      exit 1
    fi
  else
    echo "Skip missing: $src"
  fi
}

echo "Step 1: Archive and clear large VS Code storages"
archive_path "$HOME_DIR/Library/Application Support/Code/User/workspaceStorage" "vscode_workspaceStorage"
# Global storage may contain extension state; archive then remove to free space safely
archive_path "$HOME_DIR/Library/Application Support/Code/User/globalStorage" "vscode_globalStorage"

echo "Step 2: Clear macOS/user caches"
targets=(
  "$HOME_DIR/Library/Caches"
  "$HOME_DIR/.cache"
)
for t in "${targets[@]}"; do
  if [[ -d "$t" ]]; then
    echo "Clearing: $t"
    find "$t" -mindepth 1 -maxdepth 1 -exec rm -rf {} + || true
  fi
done

echo "Step 3: Clear package manager caches"
if [[ -d "$HOME_DIR/.pnpm-store" ]]; then
  echo "Removing pnpm store: $HOME_DIR/.pnpm-store"
  rm -rf "$HOME_DIR/.pnpm-store"
fi
if [[ -d "$HOME_DIR/.npm" ]]; then
  echo "Removing npm cache: $HOME_DIR/.npm"
  rm -rf "$HOME_DIR/.npm"
fi

echo "Done. Current disk usage:"
df -h | sed -n '1p;/\/Volumes\//p;/\/Users\//p'

