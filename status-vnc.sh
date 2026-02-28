#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

show_process() {
    local name="$1"
    local pattern="$2"

    if check_process "$name" "$pattern"; then
        pgrep -af "$pattern" | sed 's/^/   /'
        return 0
    fi

    return 1
}

echo "============================================"
echo "📊 VNC Process Status"
echo "============================================"
echo ""

echo "📦 VNC Services:"
show_process "Xvnc" "Xvnc :${DISPLAY_NUM}" || true
show_process "Fluxbox" "fluxbox" || true
show_process "websockify" "websockify.*${NOVNC_PORT}" || true
show_process "DBus (ours)" "dbus-daemon.*${XDG_RUNTIME_DIR}" || true
echo ""

echo "🔐 VPN Status:"
XRAY_RUNNING=false
if show_process "Xray VPN" "xray run"; then
    XRAY_RUNNING=true
fi
echo ""

if [ "$XRAY_RUNNING" = true ]; then
    echo "🌍 VPN Connection Test:"
    test_vpn_connection "$SOCKS_PORT" || true
    echo ""

    echo "🔧 Proxy Settings:"
    echo "   SOCKS5: 127.0.0.1:$SOCKS_PORT"
    echo "   HTTP:   127.0.0.1:$HTTP_PORT"
    echo "   http_proxy=${http_proxy:-<not set>}"
    echo "   all_proxy=${all_proxy:-<not set>}"

    if [ -f "$PROXY_ENV_FILE" ]; then
        echo "   env file: $PROXY_ENV_FILE ✅"
    else
        echo "   env file: missing"
    fi
    echo ""
fi

if [ -f "$PID_FILE" ]; then
    mapfile -t PID_FIELDS < <(tr -s '[:space:]' '\n' < "$PID_FILE")

    VNC_PID="${PID_FIELDS[0]:-}"
    FLUXBOX_PID="${PID_FIELDS[1]:-}"
    WEBSOCKIFY_PID="${PID_FIELDS[2]:-}"
    DBUS_PID="${PID_FIELDS[3]:-}"
    XRAY_PID="${PID_FIELDS[4]:-}"

    echo "📄 PID File Contents:"
    echo "   VNC: ${VNC_PID:-?} | Fluxbox: ${FLUXBOX_PID:-?} | websockify: ${WEBSOCKIFY_PID:-?} | DBus: ${DBUS_PID:-N/A} | Xray: ${XRAY_PID:-N/A}"
    echo ""

    echo "📋 PID Status:"
    for name_pid in \
        "VNC:${VNC_PID:-}" \
        "Fluxbox:${FLUXBOX_PID:-}" \
        "websockify:${WEBSOCKIFY_PID:-}" \
        "DBus:${DBUS_PID:-}" \
        "Xray:${XRAY_PID:-}"; do
        name="${name_pid%%:*}"
        pid="${name_pid##*:}"

        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "   ✅ $name ($pid) - alive"
        elif [ -n "$pid" ]; then
            echo "   💀 $name ($pid) - dead"
        fi
    done
    echo ""
fi

echo "📺 VNC URL:"
echo "$NOVNC_URL"
echo ""

if [ -f "$VPN_LOG_FILE" ] && [ "$XRAY_RUNNING" = true ]; then
    echo "🔐 VPN log (last 5 lines):"
    tail -5 "$VPN_LOG_FILE" | sed 's/^/   /'
    echo ""
fi

if [ -f "$LOG_FILE" ]; then
    echo "📝 Desktop log (last 5 lines):"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
fi
