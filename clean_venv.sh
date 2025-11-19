#!/usr/bin/env bash
# Recursively remove committed Python venvs from the repository and add them to .gitignore
# Usage: ./tools/clean_venv.sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)

echo "Searching for venv directories to remove from git and disk..."
mapfile -t VENVS < <(git ls-files -z | tr '\0' '\n' | grep -E '/venv/|/\.venv/' || true)

if [[ ${#VENVS[@]} -eq 0 ]]; then
  echo "No committed venv directories found in tracked files."
  exit 0
fi

# Remove from git index (keep files locally if desired)
for f in "${VENVS[@]}"; do
  dir=$(dirname "$f")
  echo "Untracking and removing $dir from git..."
  git rm -r --cached "$dir" || true
  rm -rf "$dir"
done

# Add a global .gitignore entry
GITIGNORE="$REPO_ROOT/.gitignore"
if ! grep -q "**/venv/" "$GITIGNORE"; then
  echo "\n# Ignore Python virtualenvs" >> "$GITIGNORE"
  echo "**/venv/" >> "$GITIGNORE"
  echo "**/.venv/" >> "$GITIGNORE"
  git add "$GITIGNORE"
  echo "Updated .gitignore to ignore venv directories. Commit the change: git add .gitignore && git commit -m 'Add venv to .gitignore'"
fi

echo "Done. Please push your changes and rotate any keys that were inside these venvs or env files."
