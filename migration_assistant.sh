#!/usr/bin/env bash
# tools/migration_assistant.sh
# Framework Migrator – scans the repo for deprecated framework/library patterns.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ACTION="scan"
TARGET_DIR="$REPO_ROOT"
CUSTOM_PATTERN_FILE="${MIGRATION_PATTERNS_FILE:-}"

EXCLUDE_DIRS=(node_modules .git dist build .next .nuxt .expo coverage cypress/videos)

DEFAULT_PATTERNS=(
  "React\\.PropTypes|Use the standalone 'prop-types' package instead of React.PropTypes.|*.js,*.jsx,*.ts,*.tsx|medium|https://reactjs.org/docs/typechecking-with-proptypes.html"
  "componentWillReceiveProps|Replace with static getDerivedStateFromProps or componentDidUpdate.|*.js,*.jsx|high|https://reactjs.org/blog/2018/03/27/update-on-async-rendering.html"
  "componentWillMount|Move logic to the constructor or componentDidMount.|*.js,*.jsx|medium|https://reactjs.org/blog/2018/03/27/update-on-async-rendering.html"
  "@material-ui/core|Migrate to @mui/material following the MUI v5 migration guide.|*.js,*.jsx,*.ts,*.tsx|high|https://mui.com/material-ui/migration/migration-v4/"
  "django\\.conf\\.urls\\.url|Use django.urls.path/re_path; django.conf.urls.url was removed in Django 4.0.|*.py|high|https://docs.djangoproject.com/en/4.2/releases/4.0/#id2"
  "print \"|Python 2 style print detected; switch to Python 3 print() function.|*.py|medium|https://docs.python.org/3/howto/pyporting.html"
  "asyncio\\.get_event_loop\\(\\)\\.run_until_complete|Prefer asyncio.run() in Python 3.7+.|*.py|medium|https://docs.python.org/3/library/asyncio-runner.html"
  "angular\\.module\\(|Update to Angular >=2+; move logic to NgModule/Component syntax.|*.js,*.ts|medium|https://angular.io/guide/upgrade"
  "Vue\\.config\\.silent|Deprecated in Vue 3; rely on compile-time warnings or eslint-plugin-vue.|*.js,*.ts|low|https://v3-migration.vuejs.org/breaking-changes/global-api.html"
)

function usage() {
  cat <<'EOF'
Framework Migration Assistant

Usage:
  migration_assistant.sh [--scan] [--list-patterns] [--path <dir>] [--pattern-file <file>]

Options:
  --scan               Run the full scan (default action).
  --list-patterns      Print the active pattern catalog and exit.
  --path <dir>         Limit scanning to the provided directory.
  --pattern-file <file>
                       Append custom patterns from the given file (pipe-delimited entries).
  -h, --help           Show this help.

Environment:
  MIGRATION_PATTERNS_FILE can point to a custom pattern file (same format as --pattern-file).
EOF
}

function trim() {
  local input="$1"
  # shellcheck disable=SC2001
  input="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$input")"
  printf '%s' "$input"
}

function resolve_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    (cd "$dir" && pwd)
  else
    echo "Error: Directory '$dir' not found." >&2
    exit 1
  fi
}

function parse_args() {
  while (($#)); do
    case "$1" in
      --scan)
        ACTION="scan"
        ;;
      --list-patterns)
        ACTION="list"
        ;;
      --path)
        [[ -n "${2:-}" ]] || { echo "Missing argument for --path" >&2; exit 1; }
        TARGET_DIR="$(resolve_dir "$2")"
        shift
        ;;
      --pattern-file)
        [[ -n "${2:-}" ]] || { echo "Missing argument for --pattern-file" >&2; exit 1; }
        CUSTOM_PATTERN_FILE="$2"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

function gather_patterns() {
  ACTIVE_PATTERNS=("${DEFAULT_PATTERNS[@]}")

  local pattern_file=""
  if [[ -n "$CUSTOM_PATTERN_FILE" ]]; then
    pattern_file="$CUSTOM_PATTERN_FILE"
  elif [[ -n "${MIGRATION_PATTERNS_FILE:-}" ]]; then
    pattern_file="$MIGRATION_PATTERNS_FILE"
  fi

  if [[ -n "$pattern_file" ]]; then
    if [[ ! -f "$pattern_file" ]]; then
      echo "⚠️  Custom pattern file '$pattern_file' not found. Skipping." >&2
    else
      while IFS='|' read -r pattern suggestion glob severity reference; do
        [[ -z "$pattern" || "${pattern:0:1}" == "#" ]] && continue
        pattern="$(trim "$pattern")"
        suggestion="$(trim "${suggestion:-}")"
        glob="$(trim "${glob:-*}")"
        severity="$(trim "${severity:-medium}")"
        reference="$(trim "${reference:-N/A}")"
        ACTIVE_PATTERNS+=("$pattern|$suggestion|$glob|$severity|$reference")
      done <"$pattern_file"
    fi
  fi
}

function print_patterns() {
  printf "%-40s | %-8s | %s\n" "Pattern" "Severity" "Suggestion"
  printf -- "--------------------------------------------------------------------------------\n"
  for entry in "${ACTIVE_PATTERNS[@]}"; do
    IFS='|' read -r pattern suggestion _ severity reference <<<"$entry"
    printf "%-40s | %-8s | %s (ref: %s)\n" "$pattern" "$severity" "$suggestion" "$reference"
  done
}

function log_header() {
  echo "=== Framework Migration Assistant ==="
  echo "Target directory : $TARGET_DIR"
  if command -v rg >/dev/null 2>&1; then
    echo "Search engine    : ripgrep"
  else
    echo "Search engine    : grep"
  fi
  echo "Patterns loaded  : ${#ACTIVE_PATTERNS[@]}"
  echo ""
}

function build_include_args() {
  local glob_string="$1"
  INCLUDE_ARGS=()
  IFS=',' read -r -a globs <<<"$glob_string"
  for glob in "${globs[@]}"; do
    glob="$(trim "$glob")"
    [[ -z "$glob" || "$glob" == "*" ]] && continue
    INCLUDE_ARGS+=("$glob")
  done
}

function run_scan() {
  local total_findings=0
  local patterns_with_hits=0

  for entry in "${ACTIVE_PATTERNS[@]}"; do
    IFS='|' read -r pattern suggestion glob severity reference <<<"$entry"
    build_include_args "$glob"
    echo "▶ Pattern: $pattern"
    if ((${#INCLUDE_ARGS[@]})); then
      echo "  Files  : ${INCLUDE_ARGS[*]}"
    else
      echo "  Files  : (all files)"
    fi
    echo "  Severity: $severity"
    echo "  Ref    : $reference"

    local results=""
    if command -v rg >/dev/null 2>&1; then
      local cmd=(rg --color=never --line-number --with-filename "$pattern" "$TARGET_DIR")
      if ((${#INCLUDE_ARGS[@]})); then
        for include in "${INCLUDE_ARGS[@]}"; do
          cmd+=(--glob "$include")
        done
      fi
      for exclude in "${EXCLUDE_DIRS[@]}"; do
        cmd+=(--glob "!$exclude/**")
      done
      results="$("${cmd[@]}" 2>/dev/null || true)"
    else
      local cmd=(grep -RIn --color=never "$pattern" "$TARGET_DIR")
      if ((${#INCLUDE_ARGS[@]})); then
        for include in "${INCLUDE_ARGS[@]}"; do
          cmd+=(--include="$include")
        done
      fi
      for exclude in "${EXCLUDE_DIRS[@]}"; do
        cmd+=(--exclude-dir="$exclude")
      done
      results="$("${cmd[@]}" 2>/dev/null || true)"
    fi

    if [[ -n "$results" ]]; then
      patterns_with_hits=$((patterns_with_hits + 1))
      local count
      count="$(wc -l <<<"$results" | tr -d '[:space:]')"
      total_findings=$((total_findings + count))
      echo "  🚨 Found $count occurrence(s):"
      echo "$results" | sed 's/^/    /'
      echo "  💡 Suggestion: $suggestion"
    else
      echo "  ✅ No matches detected."
    fi

    echo ""
  done

  if ((total_findings > 0)); then
    echo "Summary: $total_findings potential migration issues across $patterns_with_hits pattern(s)."
    return 1
  else
    echo "Summary: ✅ No deprecated patterns detected in the scanned files."
    return 0
  fi
}

parse_args "$@"
gather_patterns

if [[ "$ACTION" == "list" ]]; then
  print_patterns
  exit 0
fi

log_header
run_scan
