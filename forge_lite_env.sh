#!/usr/bin/env bash
#
# forge_lite_env.sh — Development environment manager for ForgeTM Lite
#
# Usage:
#   FORGE_LITE_DIR=/path/to/forge-lite bash tools/forge_lite_env.sh [command]
#
# Commands:
#   dev         - Start Expo dev server
#   api         - Start FastAPI backend
#   test        - Run all tests
#   lint        - Run linters
#   build       - Build for production
#   setup       - Initial project setup
#

set -euo pipefail

FORGE_LITE_DIR="${FORGE_LITE_DIR:-apps/forge-lite}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[ForgeTM Lite]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[ForgeTM Lite]${NC} $1"
}

log_error() {
    echo -e "${RED}[ForgeTM Lite]${NC} $1"
}

check_dir() {
    if [[ ! -d "$FORGE_LITE_DIR" ]]; then
        log_error "Directory not found: $FORGE_LITE_DIR"
        log_info "Set FORGE_LITE_DIR environment variable to the correct path"
        exit 1
    fi
}

check_deps() {
    log_info "Checking dependencies..."

    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js 18+"
        exit 1
    fi

    if ! command -v pnpm &> /dev/null; then
        log_error "pnpm not found. Installing..."
        npm install -g pnpm
    fi

    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found. Please install Python 3.11+"
        exit 1
    fi

    log_info "Dependencies OK"
}

cmd_setup() {
    log_info "Setting up ForgeTM Lite..."
    check_dir
    check_deps

    cd "$FORGE_LITE_DIR"

    # Install frontend dependencies
    log_info "Installing frontend dependencies..."
    pnpm install

    # Install backend dependencies
    if [[ -d "api" ]]; then
        log_info "Installing backend dependencies..."
        cd api
        if [[ ! -d "venv" ]]; then
            python3 -m venv venv
        fi
        source venv/bin/activate
        pip install -r requirements.txt
        cd ..
    fi

    # Copy env file if it doesn't exist
    if [[ ! -f ".env.local" ]] && [[ -f ".env.example" ]]; then
        log_info "Creating .env.local from template..."
        cp .env.example .env.local
        log_warn "Please edit .env.local with your Supabase credentials"
    fi

    log_info "Setup complete! 🎉"
    log_info "Next steps:"
    log_info "  1. Edit .env.local with your Supabase credentials"
    log_info "  2. Run: bash tools/forge_lite_env.sh dev"
}

cmd_dev() {
    log_info "Starting Expo dev server..."
    check_dir

    cd "$FORGE_LITE_DIR"

    # Load environment variables
    if [[ -f ".env.local" ]]; then
        set -a
        source .env.local
        set +a
    fi

    pnpm dev
}

cmd_api() {
    log_info "Starting FastAPI backend..."
    check_dir

    if [[ ! -d "$FORGE_LITE_DIR/api" ]]; then
        log_error "API directory not found: $FORGE_LITE_DIR/api"
        exit 1
    fi

    cd "$FORGE_LITE_DIR/api"

    # Activate virtual environment if it exists
    if [[ -d "venv" ]]; then
        source venv/bin/activate
    fi

    # Start FastAPI with hot reload
    uvicorn main:app --reload --port 8000
}

cmd_test() {
    log_info "Running tests..."
    check_dir

    cd "$FORGE_LITE_DIR"

    # Frontend tests
    log_info "Running frontend tests..."
    pnpm test

    # Backend tests
    if [[ -d "api" ]]; then
        log_info "Running backend tests..."
        cd api
        if [[ -d "venv" ]]; then
            source venv/bin/activate
        fi
        pytest
        cd ..
    fi

    log_info "All tests passed! ✅"
}

cmd_lint() {
    log_info "Running linters..."
    check_dir

    cd "$FORGE_LITE_DIR"

    # Frontend lint
    log_info "Linting frontend..."
    pnpm lint

    # Backend lint
    if [[ -d "api" ]]; then
        log_info "Linting backend..."
        cd api
        if [[ -d "venv" ]]; then
            source venv/bin/activate
        fi
        if command -v ruff &> /dev/null; then
            ruff check .
        else
            log_warn "ruff not found, skipping Python linting"
        fi
        cd ..
    fi

    log_info "Linting complete! ✅"
}

cmd_build() {
    log_info "Building for production..."
    check_dir

    cd "$FORGE_LITE_DIR"

    # Load environment variables
    if [[ -f ".env.local" ]]; then
        set -a
        source .env.local
        set +a
    fi

    if command -v pnpm &> /dev/null; then
        if pnpm dlx eas --version &> /dev/null; then
            log_info "Running EAS production builds for iOS and Android"
            pnpm dlx eas build --platform ios --profile production
            pnpm dlx eas build --platform android --profile production
        else
            log_warn "EAS CLI not available. Install with: pnpm add -D eas-cli or npm i -g eas-cli"
        fi
    else
        log_warn "pnpm not available; cannot run EAS build"
    fi

    log_info "Build step finished (check EAS for artifacts) 🚀"
}

cmd_help() {
    cat << EOF
ForgeTM Lite Environment Manager

Usage:
  FORGE_LITE_DIR=/path/to/forge-lite bash tools/forge_lite_env.sh [command]

Commands:
  setup       - Initial project setup (install deps, create .env)
  dev         - Start Expo dev server
  api         - Start FastAPI backend
  test        - Run all tests (frontend + backend)
  lint        - Run all linters
  build       - Build for production
  help        - Show this help message

Environment Variables:
  FORGE_LITE_DIR    - Path to ForgeTM Lite directory (default: apps/forge-lite)

Examples:
  # Setup project
  bash tools/forge_lite_env.sh setup

  # Start dev server
  bash tools/forge_lite_env.sh dev

  # Start API server (in separate terminal)
  bash tools/forge_lite_env.sh api

  # Run tests
  bash tools/forge_lite_env.sh test

EOF
}

# Main command dispatcher
COMMAND="${1:-help}"

case "$COMMAND" in
    setup)
        cmd_setup
        ;;
    dev)
        cmd_dev
        ;;
    api)
        cmd_api
        ;;
    test)
        cmd_test
        ;;
    lint)
        cmd_lint
        ;;
    build)
        cmd_build
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
