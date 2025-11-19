#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[api_keys_check] validating API key configuration"

# Required API keys by file (space-separated)
FORGETM_ENV_KEYS="GEMINI_API_KEY GEMINI_API_KEY_FORGETM DEEPSEEK_API_KEY OPENAI_API_KEY POLYGON_API_KEY LITELLM_API_KEY"
BACKEND_ENV_KEYS="GEMINI_API_KEY GEMINI_API_KEY_FORGETM DEEPSEEK_API_KEY OPENAI_API_KEY POLYGON_API_KEY LITELLM_API_KEY"
GOBLINOS_ENV_KEYS="GEMINI_API_KEY DEEPSEEK_API_KEY POLYGON_API_KEY OPENAI_API_KEY LITELLM_API_KEY"

# Files to check
ENV_FILES=(
  "${REPO_ROOT}/ForgeTM/.env.example"
  "${REPO_ROOT}/ForgeTM/apps/backend/.env.example"
  "${REPO_ROOT}/GoblinOS/.env.example"
)

# Check each .env.example file for required keys
check_file_keys() {
  local env_file="$1"
  local required_keys="$2"

  if [ ! -f "$env_file" ]; then
    echo "[api_keys_check] error: $env_file not found" >&2
    exit 1
  fi

  echo "[api_keys_check] checking $env_file"

  for key in $required_keys; do
    if ! grep -q "^${key}=" "$env_file"; then
      echo "[api_keys_check] error: $key not found in $env_file" >&2
      exit 1
    fi
  done
}

# Check each file with its specific required keys
check_file_keys "${REPO_ROOT}/ForgeTM/.env.example" "$FORGETM_ENV_KEYS"
check_file_keys "${REPO_ROOT}/ForgeTM/apps/backend/.env.example" "$BACKEND_ENV_KEYS"
check_file_keys "${REPO_ROOT}/GoblinOS/.env.example" "$GOBLINOS_ENV_KEYS"

# Check that API_KEYS_MANAGEMENT.md exists and is up to date
# The canonical location for workspace docs is under `Obsidian/`.
# Update: point to `Obsidian/API_KEYS_MANAGEMENT.md` which is referenced across the repo.
API_KEYS_DOC="${REPO_ROOT}/Obsidian/API_KEYS_MANAGEMENT.md"
if [ ! -f "$API_KEYS_DOC" ]; then
  echo "[api_keys_check] error: $API_KEYS_DOC not found" >&2
  exit 1
fi

echo "[api_keys_check] checking API_KEYS_MANAGEMENT.md"

# Verify all required keys are documented (check all keys from all files)
ALL_KEYS="GEMINI_API_KEY GEMINI_API_KEY_FORGETM DEEPSEEK_API_KEY OPENAI_API_KEY POLYGON_API_KEY LITELLM_API_KEY"

for key in $ALL_KEYS; do
  if ! grep -q "$key" "$API_KEYS_DOC"; then
    echo "[api_keys_check] error: $key not documented in $API_KEYS_DOC" >&2
    exit 1
  fi
done

# Check that .env files are properly ignored (if they exist)
GITIGNORE="${REPO_ROOT}/.gitignore"
if [ -f "$GITIGNORE" ]; then
  echo "[api_keys_check] checking .gitignore for security"

  # Check that actual .env files are ignored
  IGNORED_PATTERNS=(
    "ForgeTM/.env"
    "GoblinOS/.env"
    ".credentials.vault"
  )

  for pattern in "${IGNORED_PATTERNS[@]}"; do
    if ! grep -q "$pattern" "$GITIGNORE"; then
      echo "[api_keys_check] warning: $pattern not found in .gitignore" >&2
    fi
  done
fi

echo "[api_keys_check] API key configuration is valid"

