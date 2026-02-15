#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

build_app() {
    echo "🔨 Building Antigravity..."

    local previous_dir
    previous_dir="$PWD"
    cd "$SCRIPT_DIR"
    nix build . --impure 2>&1 | sed '/warning: Git tree/d'
    cd "$previous_dir"

    if [ ! -x "$SCRIPT_DIR/result/bin/antigravity" ]; then
        log_error "Build finished but result/bin/antigravity is missing"
        return 1
    fi

    echo "🌐 Setting up browser..."
    mkdir -p "$HOME/.local/bin"

    local built_browser
    built_browser="$(readlink -f "$SCRIPT_DIR/result/bin/google-chrome" 2>/dev/null || true)"
    if [ -n "$built_browser" ] && [ -x "$built_browser" ]; then
        ln -sf "$built_browser" "$BROWSER_CMD"
        local chromium_version
        chromium_version="$($BROWSER_CMD --version 2>/dev/null | head -1 || echo "unknown")"
        echo "   ✅ Browser: $BROWSER_CMD -> $built_browser"
        echo "   ✅ Version: $chromium_version"
    else
        echo "   ⚠️  Could not find built google-chrome at ./result/bin/google-chrome"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    build_app
fi
