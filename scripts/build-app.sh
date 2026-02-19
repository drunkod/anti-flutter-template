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
    nix build "path:$SCRIPT_DIR#default" --impure --no-write-lock-file 2>&1 | sed '/warning: Git tree/d'
    cd "$previous_dir"

    if [ ! -x "$SCRIPT_DIR/result/bin/antigravity" ]; then
        log_error "Build finished but result/bin/antigravity is missing"
        return 1
    fi

    echo "🌐 Setting up browser..."
    mkdir -p "$(dirname "$BROWSER_CMD")" "$(dirname "$CAMOUFOX_BROWSER1_CMD")" "$(dirname "$CAMOUFOX_BROWSER2_CMD")"

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

    local built_camoufox_1 built_camoufox_2
    built_camoufox_1="$(readlink -f "$SCRIPT_DIR/result/bin/camoufox-browser-1" 2>/dev/null || true)"
    built_camoufox_2="$(readlink -f "$SCRIPT_DIR/result/bin/camoufox-browser-2" 2>/dev/null || true)"

    if [ -n "$built_camoufox_1" ] && [ -x "$built_camoufox_1" ]; then
        ln -sf "$built_camoufox_1" "$CAMOUFOX_BROWSER1_CMD"
        echo "   ✅ Camoufox #1: $CAMOUFOX_BROWSER1_CMD -> $built_camoufox_1"
    else
        echo "   ⚠️  Could not find built camoufox-browser-1 at ./result/bin/camoufox-browser-1"
    fi

    if [ -n "$built_camoufox_2" ] && [ -x "$built_camoufox_2" ]; then
        ln -sf "$built_camoufox_2" "$CAMOUFOX_BROWSER2_CMD"
        echo "   ✅ Camoufox #2: $CAMOUFOX_BROWSER2_CMD -> $built_camoufox_2"
    else
        echo "   ⚠️  Could not find built camoufox-browser-2 at ./result/bin/camoufox-browser-2"
    fi

    if [ -x "$SCRIPT_DIR/result/bin/camoufox" ]; then
        local camoufox_version
        camoufox_version="$("$SCRIPT_DIR/result/bin/camoufox" --version 2>&1 | head -1 || true)"
        if [ -z "$camoufox_version" ]; then
            camoufox_version="$("$SCRIPT_DIR/result/bin/camoufox-bin" --version 2>&1 | head -1 || true)"
        fi
        if [ -n "$camoufox_version" ]; then
            echo "   ✅ Camoufox version: $camoufox_version"
        else
            echo "   ⚠️  Camoufox did not return a version string"
            echo "      Check launch stderr in ~/.fluxbox-debug.log after clicking Camoufox in Fluxbox"
        fi
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    build_app
fi
