#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/artifacts/secrets"
SARIF_DIR="${REPO_ROOT}/artifacts/sarif"

mkdir -p "$OUT_DIR" "$SARIF_DIR"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--staged|--full|--ci] [--output-dir DIR]

Options:
  --staged     Run fast checks on staged files (for pre-commit)
  --full       Run full local scan (all scanners)
  --ci         Run in CI mode (full scan, produce SARIF outputs)
  --output-dir DIR  Write outputs to DIR (default: artifacts/secrets)
  -h|--help    Show this help
EOF
  exit 0
}

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged) MODE=staged; shift ;;
    --full) MODE=full; shift ;;
    --ci) MODE=ci; shift ;;
    --output-dir) OUT_DIR="$2"; SARIF_DIR="$2"/../sarif; mkdir -p "$OUT_DIR" "$SARIF_DIR"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

run_detect_secrets() {
  local target_files="$1"
  local out_json="$OUT_DIR/detect-secrets.json"
  if command -v detect-secrets >/dev/null 2>&1; then
    if [[ -n "$target_files" ]]; then
      detect-secrets scan $target_files --json > "$out_json" || true
    else
      detect-secrets scan --json > "$out_json" || true
    fi
    echo "detect-secrets output: $out_json"
  else
    echo "detect-secrets not installed; skipping detect-secrets" >&2
  fi
}

run_gitleaks() {
  local src="$1"
  local out_json="$OUT_DIR/gitleaks.json"
  if command -v gitleaks >/dev/null 2>&1; then
    # prefer detect on repo; --report-format json is supported in modern gitleaks
    gitleaks detect --source "$src" --config "$SCRIPT_DIR/gitleaks.toml" --report-path "$out_json" || true
    echo "gitleaks output: $out_json"
  else
    echo "gitleaks not installed; skipping gitleaks" >&2
  fi
}

run_trufflehog() {
  local src="$1"
  local out_json="$OUT_DIR/trufflehog.json"
  if command -v trufflehog >/dev/null 2>&1; then
    trufflehog filesystem --directory "$src" --json > "$out_json" || true
    echo "trufflehog output: $out_json"
  elif command -v trufflehog3 >/dev/null 2>&1; then
    trufflehog3 filesystem --directory "$src" --json > "$out_json" || true
    echo "trufflehog3 output: $out_json"
  else
    echo "trufflehog not installed; skipping trufflehog" >&2
  fi
}

convert_to_sarif() {
  local scanner="$1"
  local in_json="$2"
  local out_sarif="$3"
  if [[ -f "$in_json" && -s "$in_json" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 "$SCRIPT_DIR/convert_to_sarif.py" --scanner "$scanner" --input "$in_json" --output "$out_sarif"
      echo "Wrote SARIF: $out_sarif"
    else
      echo "python3 not found: cannot convert $in_json to SARIF" >&2
    fi
  else
    echo "No findings or missing file for $scanner: $in_json" >&2
  fi
}

if [[ "$MODE" == "staged" ]]; then
  echo "Running staged secrets checks"
  # find staged files
  staged_files=$(git diff --cached --name-only --diff-filter=ACM | tr '\n' ' ')
  if [[ -z "$staged_files" ]]; then
    echo "No staged files to scan."
    exit 0
  fi
  echo "Staged files: $staged_files"
  # Run detect-secrets against staged files (best-effort)
  run_detect_secrets "$staged_files"
  # Run gitleaks on the staged patch if gitleaks is available
  if command -v gitleaks >/dev/null 2>&1; then
    # create a temp patch and run gitleaks against it
    git diff --cached > "$OUT_DIR/staged.patch" || true
    if [[ -s "$OUT_DIR/staged.patch" ]]; then
      gitleaks detect --source "$OUT_DIR/staged.patch" --report-path "$OUT_DIR/gitleaks-staged.json" || true
      echo "gitleaks staged output: $OUT_DIR/gitleaks-staged.json"
    fi
  fi
  # Exit code: non-zero if any scanner emitted JSON with findings
  # We treat presence of non-empty JSON as a warning for pre-commit (do not fail hard)
  exit 0
fi

if [[ "$MODE" == "full" || "$MODE" == "ci" ]]; then
  echo "Running full secrets scan (mode=$MODE)"
  # Full repo scans
  run_detect_secrets ""
  run_gitleaks "$REPO_ROOT"
  run_trufflehog "$REPO_ROOT"

  # Convert outputs to SARIF when possible
  convert_to_sarif "gitleaks" "$OUT_DIR/gitleaks.json" "$SARIF_DIR/gitleaks.sarif" || true
  convert_to_sarif "trufflehog" "$OUT_DIR/trufflehog.json" "$SARIF_DIR/trufflehog.sarif" || true
  convert_to_sarif "detect-secrets" "$OUT_DIR/detect-secrets.json" "$SARIF_DIR/detect-secrets.sarif" || true

  # Summarize results
  echo "Artifacts:"
  ls -la "$OUT_DIR" || true
  ls -la "$SARIF_DIR" || true

  # Exit codes: 0 means completed; CI will decide whether to fail on findings
  exit 0
fi

usage
