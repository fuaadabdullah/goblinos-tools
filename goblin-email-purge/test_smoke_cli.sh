#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# ensure run.sh exists and is executable
./run.sh audit --config config.example.yaml

if [ -d "reports" ]; then
  echo "OK: reports dir exists"
else
  echo "ERROR: reports dir missing"; exit 1
fi

count=$(ls reports/*.json 2>/dev/null | wc -l)
if [ "$count" -ge 1 ]; then
  echo "OK: reports files present: $count"
else
  echo "ERROR: no report files found"; exit 1
fi

echo "Smoke test passed"
