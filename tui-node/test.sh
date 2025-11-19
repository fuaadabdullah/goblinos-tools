#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP_CFG="$HERE/test-config.json"

cat > "$TMP_CFG" <<'JSON'
{
  "commands": {
    "say hello": "echo hello world"
  },
  "cwd": "${repo_root}"
}
JSON

export GOBLIN_CMD=1
node "$HERE/index.js" --config "$TMP_CFG" | tee /tmp/goblin_tui_node_test.log

if grep -q "hello world" /tmp/goblin_tui_node_test.log; then
  echo "OK: output contains hello world"
  exit 0
else
  echo "FAIL: expected hello world in output"
  exit 2
fi
