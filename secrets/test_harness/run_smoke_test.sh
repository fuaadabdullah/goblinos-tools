#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SARIF_DIR="$REPO_ROOT/artifacts/sarif"

echo "Running secrets smoke test: verifying SARIF outputs"

if [[ ! -d "$SARIF_DIR" ]]; then
  echo "SARIF directory not found: $SARIF_DIR" >&2
  exit 2
fi

found=false
for f in "$SARIF_DIR"/*.sarif; do
  if [[ -f "$f" ]]; then
    echo "Checking $f"
    if python3 - <<PY
import json,sys
try:
    with open(r"$f","r") as fh:
        j=json.load(fh)
    if not isinstance(j.get('runs'), list):
        print('Invalid SARIF (missing runs)')
        sys.exit(2)
except Exception as e:
    print('Failed to parse SARIF:', e)
    sys.exit(2)
sys.exit(0)
PY
    then
      found=true
    else
      echo "SARIF validation failed for $f" >&2
      exit 3
    fi
  fi
done

if [[ "$found" != "true" ]]; then
  echo "No SARIF files found in $SARIF_DIR" >&2
  exit 2
fi

echo "Smoke test passed: SARIF artifacts present and valid."
exit 0
