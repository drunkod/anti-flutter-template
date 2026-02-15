#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_fluxbox() {
    echo "🖥️  Configuring Fluxbox..."

    mkdir -p "$HOME/.fluxbox"

    TERMINAL_BIN="$(command -v xterm 2>/dev/null || echo "xterm")"
    SHELL_BIN="$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "/bin/sh")"

    render_template \
        "$SCRIPT_DIR/config/fluxbox/menu.template" \
        "$HOME/.fluxbox/menu" \
        "TERMINAL_BIN=$TERMINAL_BIN" \
        "SHELL_BIN=$SHELL_BIN" \
        "BROWSER_CMD=$BROWSER_CMD" \
        "SCRIPT_DIR=$SCRIPT_DIR" \
        "SOCKS_PORT=$SOCKS_PORT" \
        "VPN_LOG_FILE=$VPN_LOG_FILE" \
        "LOG_FILE=$LOG_FILE"

    render_template \
        "$SCRIPT_DIR/config/fluxbox/keys.template" \
        "$HOME/.fluxbox/keys" \
        "TERMINAL_BIN=$TERMINAL_BIN" \
        "BROWSER_CMD=$BROWSER_CMD"

    cp "$SCRIPT_DIR/config/fluxbox/init" "$HOME/.fluxbox/init"
    cp "$SCRIPT_DIR/config/fluxbox/startup" "$HOME/.fluxbox/startup"
    chmod +x "$HOME/.fluxbox/startup"
    cp "$SCRIPT_DIR/config/Xresources" "$HOME/.Xresources"

    render_template \
        "$SCRIPT_DIR/config/proxychains.conf.template" \
        "$PROXYCHAINS_CONF" \
        "SOCKS_PORT=$SOCKS_PORT"

    echo "   ✅ Fluxbox menu, keys, and theme configured"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fluxbox
fi
