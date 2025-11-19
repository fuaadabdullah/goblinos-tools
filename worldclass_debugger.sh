#!/usr/bin/env bash
# WorldClass Debugger - lightweight dev triage helper
# Usage: tools/worldclass_debugger.sh [mode]
# Modes:
#   audit  - run lint + type checks (tools/lint_all.sh)
#   probe  - run smoke probes (tools/smoke.sh)
#   jobs   - query the local jobs endpoint (http://127.0.0.1:8000/api/jobs)

set -euo pipefail
MODE=${1:-audit}
WORKDIR=$(cd "$(dirname "$0")/.." && pwd)

# Spinner function for progress indication
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

echo "[worldclass-debugger] mode=$MODE"
cd "$WORKDIR"

case "$MODE" in
  audit)
    echo "Running repository lint + type checks (tools/lint_all.sh)"
    bash tools/lint_all.sh &
    spinner $!
    ;;
  probe)
    if [ -x "tools/smoke.sh" ]; then
      echo "Running smoke probe (tools/smoke.sh)"
      bash tools/smoke.sh &
      spinner $!
    else
      echo "No smoke.sh found or not executable. Falling back to lint checks."
      bash tools/lint_all.sh &
      spinner $!
    fi
    ;;
  jobs)
    echo "Querying local jobs endpoint"
    if command -v curl >/dev/null 2>&1; then
      curl -sS -f http://127.0.0.1:8000/api/jobs || echo "Failed to fetch /api/jobs (server down?)"
    else
      echo "curl not available in PATH"
      exit 2
    fi
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [audit|probe|jobs]"
    exit 2
    ;;
esac

echo "[worldclass-debugger] done"
