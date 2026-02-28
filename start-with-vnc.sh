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

on_error() {
    local line="$1"
    echo "❌ Script failed at line $line"
    "$SCRIPT_DIR/stop-vnc.sh" || true
}
trap 'on_error "$LINENO"' ERR

export DISPLAY=":$DISPLAY_NUM"
export NIXPKGS_ALLOW_UNFREE=1

echo "============================================"
echo "🚀 VNC Desktop Launcher (with VPN)"
echo "============================================"

# Fluxbox executes menu/keys "Exec" entries via shell; ensure it points to a real binary.
if [ -z "${SHELL:-}" ] || [ ! -x "${SHELL:-}" ]; then
    SHELL_CANDIDATE="$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || true)"
    if [ -n "$SHELL_CANDIDATE" ] && [ -x "$SHELL_CANDIDATE" ]; then
        export SHELL="$SHELL_CANDIDATE"
    fi
fi

echo "🧹 Cleaning up previous instances..."
if [ -f "$PID_FILE" ]; then
    "$SCRIPT_DIR/stop-vnc.sh" >/dev/null 2>&1 || true
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
    echo "ℹ️  No VPN config found. Proceeding with direct connection."
fi

setup_fluxbox
start_vnc_server

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
echo "============================================"

# Desktop-only PID format: VNC Fluxbox websockify DBus Xray (no app PID).
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID ${DBUS_PID:-} ${XRAY_PID:-}" > "$PID_FILE"

# Stay alive for cloud IDE previews.
echo "🔄 Keeping alive (waiting on websockify PID $WEBSOCKIFY_PID)..."
wait "$WEBSOCKIFY_PID" 2>/dev/null || true
