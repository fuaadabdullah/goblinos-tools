#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[lint_all] running repository lint checks"

# Ensure pnpm is available before continuing
if ! command -v pnpm >/dev/null 2>&1; then
  echo "[lint_all] error: pnpm is not installed. Install pnpm to continue." >&2
  exit 1
fi

# GoblinOS linting (TypeScript / Biome)
if [ -d "${REPO_ROOT}/GoblinOS" ]; then
  echo "[lint_all] pnpm -C GoblinOS lint"
  pnpm -C "${REPO_ROOT}/GoblinOS" lint
else
  echo "[lint_all] warning: GoblinOS directory not found, skipping."
fi

# Security checks
if [ -f "${REPO_ROOT}/tools/security_check.sh" ]; then
  echo "[lint_all] bash tools/security_check.sh"
  bash "${REPO_ROOT}/tools/security_check.sh"
else
  echo "[lint_all] warning: security_check.sh not found, skipping security checks."
fi

# API keys configuration validation
if [ -f "${REPO_ROOT}/tools/api_keys_check.sh" ]; then
  echo "[lint_all] bash tools/api_keys_check.sh"
  bash "${REPO_ROOT}/tools/api_keys_check.sh"
else
  echo "[lint_all] warning: api_keys_check.sh not found, skipping API keys validation."
fi

# Placeholder for ForgeTM backend linting (FastAPI / Python)
if [ -d "${REPO_ROOT}/ForgeTM/apps/backend" ]; then
  BACKEND_DIR="${REPO_ROOT}/ForgeTM/apps/backend"
  VENV_ACTIVATE="${BACKEND_DIR}/.venv/bin/activate"
  if [ -f "$VENV_ACTIVATE" ]; then
    echo "[lint_all] running mypy in ForgeTM/apps/backend"
    (cd "$BACKEND_DIR" && source "$VENV_ACTIVATE" && python -m mypy src)
  else
    echo "[lint_all] warning: virtualenv not found at $VENV_ACTIVATE; skipping mypy for backend"
  fi

  if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "[lint_all] pre-commit run --all-files --config ForgeTM/apps/backend/.pre-commit-config.yaml"
    pre-commit run --all-files --config "${REPO_ROOT}/ForgeTM/apps/backend/.pre-commit-config.yaml" || true
  else
    echo "[lint_all] warning: not in a git repository, skipping pre-commit checks"
  fi
fi

echo "[lint_all] completed"
