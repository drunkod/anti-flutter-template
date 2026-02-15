#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=./scripts/setup-fonts.sh
source "$SCRIPT_DIR/scripts/setup-fonts.sh"
# shellcheck source=./scripts/setup-dbus.sh
source "$SCRIPT_DIR/scripts/setup-dbus.sh"
# shellcheck source=./scripts/setup-gpu-env.sh
source "$SCRIPT_DIR/scripts/setup-gpu-env.sh"
# shellcheck source=./scripts/setup-fluxbox.sh
source "$SCRIPT_DIR/scripts/setup-fluxbox.sh"
# shellcheck source=./scripts/start-vnc-server.sh
source "$SCRIPT_DIR/scripts/start-vnc-server.sh"
# shellcheck source=./scripts/build-app.sh
source "$SCRIPT_DIR/scripts/build-app.sh"
# shellcheck source=./scripts/launch-app.sh
source "$SCRIPT_DIR/scripts/launch-app.sh"

on_error() {
    local line="$1"
    echo "❌ Script failed at line $line"
    "$SCRIPT_DIR/stop-vnc.sh" || true
}
trap 'on_error "$LINENO"' ERR

export DISPLAY=":$DISPLAY_NUM"
export NIXPKGS_ALLOW_UNFREE=1

echo "============================================"
echo "🚀 Antigravity VNC Launcher (with VPN)"
echo "============================================"
echo ""
echo "🔍 DEBUG: Environment"
echo "   SCRIPT_DIR=$SCRIPT_DIR"
echo "   DISPLAY=$DISPLAY"
echo "   DISPLAY_NUM=$DISPLAY_NUM"
echo "   VNC_PORT=$VNC_PORT"
echo "   NOVNC_PORT=$NOVNC_PORT"
echo "   PORT=${PORT:-<not set>}"
echo "   BROWSER_CMD=$BROWSER_CMD"
echo "   HOME=$HOME"
echo "   PATH (first 200):  ${PATH:0:200}"
echo "   which xterm:  $(command -v xterm 2>/dev/null || echo 'NOT FOUND')"
echo "   which bash:   $(command -v bash 2>/dev/null || echo 'NOT FOUND')"
echo "   which dbus-uuidgen: $(command -v dbus-uuidgen 2>/dev/null || echo 'NOT FOUND')"
echo "   which xray:   $(command -v xray 2>/dev/null || echo 'NOT FOUND')"
echo "   which fluxbox: $(command -v fluxbox 2>/dev/null || echo 'NOT FOUND')"
echo "   which Xvnc:   $(command -v Xvnc 2>/dev/null || echo 'NOT FOUND')"
echo "   which websockify: $(command -v websockify 2>/dev/null || echo 'NOT FOUND')"
echo "   which curl:   $(command -v curl 2>/dev/null || echo 'NOT FOUND')"
echo "   /bin/sh:      $(ls -la /bin/sh 2>/dev/null || echo 'MISSING!')"
echo ""

# Fluxbox uses /bin/sh -c to execute menu commands.
# In Nix-based environments (IDX), /bin/sh may not exist, causing all
# menu items to silently fail. Create a symlink if missing.
if [ ! -f /bin/sh ]; then
    echo "⚠️  /bin/sh not found — creating symlink (needed by Fluxbox)"
    BASH_BIN="$(command -v bash 2>/dev/null || true)"
    if [ -n "$BASH_BIN" ]; then
        mkdir -p /bin 2>/dev/null || sudo mkdir -p /bin 2>/dev/null || true
        ln -sf "$BASH_BIN" /bin/sh 2>/dev/null || sudo ln -sf "$BASH_BIN" /bin/sh 2>/dev/null || true
        if [ -f /bin/sh ]; then
            echo "   ✅ Created /bin/sh -> $BASH_BIN"
        else
            echo "   ❌ Could not create /bin/sh — menu items will not work"
        fi
    fi
else
    echo "✅ /bin/sh exists: $(readlink -f /bin/sh 2>/dev/null || echo '/bin/sh')"
fi

echo "🧹 Checking for existing Antigravity instances..."
kill_by_pattern "$APP_PATTERN" 1

if [ -f "$LOCK_FILE" ]; then
    LOCK_PID="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "⚠️  Antigravity is already running (PID $LOCK_PID)"
        echo "   Run ./stop-vnc.sh to stop it first"
        exit 1
    fi
    rm -f "$LOCK_FILE"
fi

rm -f "$PID_FILE"

setup_fonts
setup_dbus
setup_gpu_env

VPN_ENABLED=false
XRAY_PID=""
VPN_CONFIG=""

if [ -f "$SCRIPT_DIR/$VPN_CONFIG_FILE" ]; then
    VPN_CONFIG="$SCRIPT_DIR/$VPN_CONFIG_FILE"
elif [ -f "$SCRIPT_DIR/$VPN_REALITY_CONFIG_FILE" ]; then
    VPN_CONFIG="$SCRIPT_DIR/$VPN_REALITY_CONFIG_FILE"
fi

if [ -n "$VPN_CONFIG" ]; then
    echo ""
    echo "🔐 Starting Xray VPN Proxy..."
    if "$SCRIPT_DIR/start-vpn.sh" "$VPN_CONFIG"; then
        VPN_ENABLED=true
        if [ -f "$PROXY_ENV_FILE" ]; then
            # shellcheck disable=SC1090
            source "$PROXY_ENV_FILE"
        fi
        XRAY_PID="$(cat "$VPN_PID_FILE" 2>/dev/null || true)"
    else
        echo "   ⚠️  VPN failed to start, continuing without VPN"
    fi
else
    echo ""
    echo "ℹ️  No VPN config found. To enable VPN:"
    echo "   Copy $VPN_CONFIG_EXAMPLE_FILE to $VPN_CONFIG_FILE and fill in server details."
    echo ""
fi

setup_fluxbox

echo ""
echo "🔍 DEBUG: Rendered fluxbox menu:"
cat "$HOME/.fluxbox/menu" 2>/dev/null || echo "   MISSING!"
echo ""
echo "🔍 DEBUG: Rendered fluxbox keys:"
cat "$HOME/.fluxbox/keys" 2>/dev/null || echo "   MISSING!"
echo ""

start_vnc_server

echo ""
echo "============================================"
echo "✅ VNC READY!"
echo ""
echo "📺 VNC URL:"
echo "$NOVNC_URL"
if [ "$VPN_ENABLED" = true ]; then
    echo ""
    echo "🔐 VPN: ACTIVE (all traffic routed through proxy)"
    echo "   SOCKS5: 127.0.0.1:$SOCKS_PORT | HTTP: 127.0.0.1:$HTTP_PORT"
fi
echo ""
echo "🖥️  Right-click desktop -> menu | Ctrl+Alt+T -> terminal | Ctrl+Alt+B -> browser"
echo "============================================"
echo ""

build_app
launch_app

if [ "$VPN_ENABLED" = true ]; then
    if [ -z "$XRAY_PID" ] && [ -f "$VPN_PID_FILE" ]; then
        XRAY_PID="$(cat "$VPN_PID_FILE" 2>/dev/null || true)"
    fi

    if [ -n "$XRAY_PID" ] && kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "   🔐 VPN confirmed running (PID $XRAY_PID)"
    else
        echo "   ⚠️  VPN is not running"
        XRAY_PID=""
    fi
fi

echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID ${DBUS_PID:-} ${XRAY_PID:-}" > "$PID_FILE"

echo ""
echo "✨ All services running in background"
echo "   Stop: ./stop-vnc.sh  |  Status: ./status-vnc.sh"
echo "   Logs: tail -f $LOG_FILE"
if [ "$VPN_ENABLED" = true ]; then
    echo "   VPN log: tail -f $VPN_LOG_FILE"
    echo "   For other shells: source $PROXY_ENV_FILE"
    echo "   Force-proxy an app: proxychains4 -f $PROXYCHAINS_CONF <cmd>"
fi
echo ""

# Stay alive — IDX expects the preview command to be a long-running process.
# When this process exits, IDX restarts the preview → infinite loop.
# Wait on websockify (the noVNC proxy) which is the actual web server.
echo "🔄 Keeping alive (waiting on websockify PID $WEBSOCKIFY_PID)..."
wait "$WEBSOCKIFY_PID" 2>/dev/null || true
