#!/usr/bin/env bash
# Portfolio environment runner for GoblinOS
# Usage: PORTFOLIO_DIR=/absolute/path/to/fuaad-portfolio-starter \
#        NEXT_PUBLIC_SITE_URL=https://example.com \
#        ./tools/portfolio_env.sh [dev|build|start]

set -euo pipefail

ACTION=${1:-dev}
PORTFOLIO_DIR=${PORTFOLIO_DIR:-}
SITE_URL=${NEXT_PUBLIC_SITE_URL:-}

if [[ -z "$PORTFOLIO_DIR" ]]; then
  echo "[portfolio_env] error: PORTFOLIO_DIR is required" >&2
  exit 1
fi

# Default local site URL for dev if not provided
if [[ -z "$SITE_URL" && "$ACTION" == "dev" ]]; then
  SITE_URL="http://localhost:3000"
fi

if [[ -z "$SITE_URL" ]]; then
  echo "[portfolio_env] warning: NEXT_PUBLIC_SITE_URL not set; some metadata may be wrong" >&2
fi

pushd "$PORTFOLIO_DIR" >/dev/null

# Ensure dependencies (no-op if already installed)
if [[ ! -d node_modules ]]; then
  echo "[portfolio_env] installing dependencies with pnpm..."
  pnpm install
fi

case "$ACTION" in
  dev)
    echo "[portfolio_env] starting dev with NEXT_PUBLIC_SITE_URL=$SITE_URL"
    NEXT_PUBLIC_SITE_URL="$SITE_URL" pnpm dev
    ;;
  build)
    echo "[portfolio_env] building with NEXT_PUBLIC_SITE_URL=$SITE_URL"
    NEXT_PUBLIC_SITE_URL="$SITE_URL" pnpm build
    ;;
  start)
    echo "[portfolio_env] starting production server with NEXT_PUBLIC_SITE_URL=$SITE_URL"
    NEXT_PUBLIC_SITE_URL="$SITE_URL" pnpm start
    ;;
  *)
    echo "[portfolio_env] unknown action: $ACTION (expected dev|build|start)" >&2
    exit 2
    ;;
fi

popd >/dev/null
