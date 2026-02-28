#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

ensure_launcher() {
    local target="$1"
    shift
    local cmd
    local found=false

    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            mkdir -p "$(dirname "$target")"
            ln -sf "$(command -v "$cmd")" "$target"
            found=true
            break
        fi
    done

    if [ "$found" = false ]; then
        echo "⚠️  Could not find any of: $* for $target"
        return 1
    fi
}

setup_fluxbox() {
    echo "🖥️  Configuring Fluxbox..."
    mkdir -p "$HOME/.fluxbox"

    TERMINAL_BIN="$(command -v xterm 2>/dev/null || echo "xterm")"
    SHELL_BIN="$(command -v bash 2>/dev/null || echo "/bin/sh")"

    ensure_launcher "$BROWSER_CMD" google-chrome chromium chromium-browser xdg-open || true
    ensure_launcher "$CAMOUFOX_BROWSER1_CMD" camoufox || true
    ensure_launcher "$CAMOUFOX_BROWSER2_CMD" camoufox || true

    render_template \
        "$SCRIPT_DIR/config/fluxbox/menu.template" \
        "$HOME/.fluxbox/menu" \
        "BROWSER_CMD=$BROWSER_CMD" \
        "CAMOUFOX_BROWSER1_CMD=$CAMOUFOX_BROWSER1_CMD" \
        "CAMOUFOX_BROWSER2_CMD=$CAMOUFOX_BROWSER2_CMD" \
        "SCRIPT_DIR=$SCRIPT_DIR" \
        "SOCKS_PORT=$SOCKS_PORT" \
        "VPN_LOG_FILE=$VPN_LOG_FILE" \
        "LOG_FILE=$LOG_FILE"

    render_template \
        "$SCRIPT_DIR/config/fluxbox/keys.template" \
        "$HOME/.fluxbox/keys" \
        "BROWSER_CMD=$BROWSER_CMD" \
        "CAMOUFOX_BROWSER1_CMD=$CAMOUFOX_BROWSER1_CMD" \
        "CAMOUFOX_BROWSER2_CMD=$CAMOUFOX_BROWSER2_CMD"

    # init is static — just copy it
    cp "$SCRIPT_DIR/config/fluxbox/init" "$HOME/.fluxbox/init"

    # startup script
    install -m 755 "$SCRIPT_DIR/config/fluxbox/startup" "$HOME/.fluxbox/startup"

    # Xresources
    cp "$SCRIPT_DIR/config/Xresources" "$HOME/.Xresources"

    # Proxychains
    render_template \
        "$SCRIPT_DIR/config/proxychains.conf.template" \
        "$PROXYCHAINS_CONF" \
        "SOCKS_PORT=$SOCKS_PORT"

    echo "   ✅ Fluxbox menu, keys, and theme configured"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fluxbox
fi
