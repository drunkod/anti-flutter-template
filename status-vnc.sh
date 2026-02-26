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
echo "📊 Antigravity VNC Status"
echo "============================================"
echo ""

echo "🎮 Application Status:"
show_process "Antigravity" "$APP_PATTERN" || true
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

    # Support both PID formats:
    # 6 fields: VNC Fluxbox websockify App DBus Xray
    # 5 fields: VNC Fluxbox websockify DBus Xray (desktop-only launcher)
    if [ "${#PID_FIELDS[@]}" -ge 6 ]; then
        APP_PID="${PID_FIELDS[3]:-}"
        DBUS_PID="${PID_FIELDS[4]:-}"
        XRAY_PID="${PID_FIELDS[5]:-}"
    else
        APP_PID=""
        DBUS_PID="${PID_FIELDS[3]:-}"
        XRAY_PID="${PID_FIELDS[4]:-}"
    fi

    echo "📄 PID File Contents:"
    echo "   VNC: ${VNC_PID:-?} | Fluxbox: ${FLUXBOX_PID:-?} | websockify: ${WEBSOCKIFY_PID:-?}"
    if [ -n "${APP_PID:-}" ]; then
        echo "   App: ${APP_PID} | DBus: ${DBUS_PID:-N/A} | Xray: ${XRAY_PID:-N/A}"
    else
        echo "   App: N/A (desktop-only mode) | DBus: ${DBUS_PID:-N/A} | Xray: ${XRAY_PID:-N/A}"
    fi
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

        if [ -n "$pid" ]; then
            if kill -0 "$pid" 2>/dev/null; then
                echo "   ✅ $name ($pid) - alive"
            else
                echo "   💀 $name ($pid) - dead"
            fi
        fi
    done
    if [ -n "${APP_PID:-}" ]; then
        if kill -0 "$APP_PID" 2>/dev/null; then
            echo "   ✅ App ($APP_PID) - alive"
        else
            echo "   💀 App ($APP_PID) - dead"
        fi
    fi
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
    echo "📝 App log (last 5 lines):"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
fi
