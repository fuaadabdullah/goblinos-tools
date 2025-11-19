#!/usr/bin/env bash
set -euo pipefail

# Safe space saver for ForgeMonorepo
# - Archives heavy directories to external drive
# - Removes regenerable caches and build artifacts
# - Never touches git history or source files

EXT_VOL_DEFAULT="/Volumes/Fuaad"
BACKUP_DIR_NAME="ForgeMonorepo-Backups"
TS="$(date +%Y-%m-%d_%H-%M-%S)"

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

echo "Repo root: $repo_root"

EXT_VOL="${1:-$EXT_VOL_DEFAULT}"
if [[ ! -d "$EXT_VOL" ]]; then
  echo "ERROR: External volume not found: $EXT_VOL"
  echo "Pass an existing mount point as first arg if different."
  exit 1
fi

backup_root="$EXT_VOL/$BACKUP_DIR_NAME"
backup_path="$backup_root/$TS"
mkdir -p "$backup_path"

echo "Backup destination: $backup_path"

pre_du=$(du -sh . 2>/dev/null | awk '{print $1}')
echo "Workspace size before: $pre_du"

archive_dir() {
  local rel_path="$1"     # path relative to repo root
  local tar_name="$2"     # base file name for tar.gz

  if [[ ! -e "$rel_path" ]]; then
    echo "Skip missing: $rel_path"
    return 0
  fi

  echo "Archiving $rel_path -> $backup_path/$tar_name.tgz"
  # Avoid macOS xattrs/AppleDouble metadata issues on non-APFS volumes
  COPYFILE_DISABLE=1 tar --no-mac-metadata -czf "$backup_path/$tar_name.tgz" -C "$repo_root" "$rel_path"
  # basic sanity: file created and >1MB
  if [[ -s "$backup_path/$tar_name.tgz" ]] && [[ $(du -m "$backup_path/$tar_name.tgz" | awk '{print $1}') -ge 1 ]]; then
    echo "Archive OK: $tar_name.tgz ($(du -h "$backup_path/$tar_name.tgz" | awk '{print $1}'))"
    echo "Removing original: $rel_path"
    rm -rf "$rel_path"
  else
    echo "ERROR: Archive failed or too small for $rel_path"
    exit 1
  fi
}

delete_dirs_by_name() {
  # find and delete directories by name patterns, pruning descent into them
  echo "Deleting cache/build directories..."
  local count=0
  while IFS= read -r d; do
    if [[ -z "$d" ]]; then continue; fi
    echo "  rm -rf $d"
    rm -rf "$d" || true
    count=$((count+1))
  done < <(find . -type d \
    \( -name .mypy_cache -o -name .pytest_cache -o -name __pycache__ -o -name .ruff_cache -o \
       -name dist -o -name build -o -name coverage -o -name htmlcov -o -name .cache -o \
       -name .next -o -name .turbo -o -name .parcel-cache \) -prune -print)

  if [[ $count -eq 0 ]]; then
    echo "No cache/build dirs found."
  else
    echo "Removed $count cache/build dirs."
  fi
}

echo "Step 1: Remove caches and build artifacts"
delete_dirs_by_name

echo "Step 2: Archive Python virtualenvs to external drive"
archive_dir "ForgeTM/apps/backend/.venv" "ForgeTM_apps_backend_venv"
archive_dir "GoblinOS/packages/goblins/forge-smithy/.venv" "GoblinOS_forge-smithy_venv"

echo "Step 3: Archive large node_modules to external drive"
archive_dir "node_modules" "root_node_modules"
archive_dir "GoblinOS/packages/goblins/overmind/dashboard/node_modules" "overmind_dashboard_node_modules"

post_du=$(du -sh . 2>/dev/null | awk '{print $1}')
echo "Workspace size after:  $post_du"

echo "Cleanup complete. Backups saved to: $backup_path"
echo "To restore a tar archive, e.g.:"
echo "  tar -xzf '$backup_path/root_node_modules.tgz' -C '$repo_root'"
echo "  tar -xzf '$backup_path/ForgeTM_apps_backend_venv.tgz' -C '$repo_root'"
