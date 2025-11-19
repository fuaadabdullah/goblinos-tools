#!/usr/bin/env bash
command -v pnpm >/dev/null 2>&1 || {
  echo "pnpm not found. Install from https://pnpm.io" >&2
  exit 1
}
