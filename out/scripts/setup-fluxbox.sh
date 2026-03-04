#!/usr/bin/env bash
# Renders Fluxbox config files (menu, keys, init, startup, Xresources, proxychains).
# Requires setup_launchers to have run first (so CMD variables are populated).

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

    render_template \
        "$SCRIPT_DIR/config/fluxbox/menu.template" \
        "$HOME/.fluxbox/menu" \
        "BROWSER_CMD=$BROWSER_CMD" \
        "BROWSER_PROXY_CMD=$BROWSER_PROXY_CMD" \
        "CAMOUFOX_BROWSER1_CMD=$CAMOUFOX_BROWSER1_CMD" \
        "CAMOUFOX_BROWSER2_CMD=$CAMOUFOX_BROWSER2_CMD" \
        "CAMOUFOX_PROXY_CMD=$CAMOUFOX_PROXY_CMD" \
        "ANTIGRAVITY_CMD=$ANTIGRAVITY_CMD" \
        "ANTIGRAVITY_PROXY_CMD=$ANTIGRAVITY_PROXY_CMD" \
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

    cp     "$SCRIPT_DIR/config/fluxbox/init"    "$HOME/.fluxbox/init"
    install -m 755 "$SCRIPT_DIR/config/fluxbox/startup" "$HOME/.fluxbox/startup"
    cp     "$SCRIPT_DIR/config/Xresources"      "$HOME/.Xresources"

    render_template \
        "$SCRIPT_DIR/config/proxychains.conf.template" \
        "$PROXYCHAINS_CONF" \
        "SOCKS_PORT=$SOCKS_PORT"

    echo "   ✅ Fluxbox configured"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fluxbox
fi
