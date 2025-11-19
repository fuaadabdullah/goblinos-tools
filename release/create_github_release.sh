#!/usr/bin/env bash
set -euo pipefail

# create_github_release.sh
# Create a GitHub Release and upload build artifacts for Tauri auto-updates.
# Requirements:
# - gh CLI installed and authenticated (GITHUB_TOKEN or gh auth login)
# - a built artifact (e.g., MyApp-macos.zip) to upload
#
# Usage:
# ./create_github_release.sh v1.2.3 ./dist/MyApp-macos.zip "Release notes"

if [[ "$#" -lt 3 ]]; then
  echo "Usage: $0 <tag> <artifact-path> <release-notes>" >&2
  exit 2
fi

TAG="$1"
ARTIFACT_PATH="$2"
RELEASE_NOTES="$3"

if [[ ! -f "$ARTIFACT_PATH" ]]; then
  echo "Artifact not found: $ARTIFACT_PATH" >&2
  exit 3
fi

REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
echo "Creating release $TAG for repo at $REPO"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required. Install from https://cli.github.com/" >&2
  exit 4
fi

echo "Creating Git tag (if missing) and release..."
git rev-parse "$TAG" >/dev/null 2>&1 || git tag "$TAG"

gh release create "$TAG" "$ARTIFACT_PATH" --notes "$RELEASE_NOTES" --title "$TAG"

echo "Uploaded $ARTIFACT_PATH to release $TAG"
echo "Tauri updater will check GitHub Releases (if configured) and fetch the artifact matching the platform and channel."
