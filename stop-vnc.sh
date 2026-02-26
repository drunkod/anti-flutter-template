#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "🧹 Stopping Antigravity VNC services..."

kill_by_pattern "$APP_PATTERN" 2

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

    for pid in "${APP_PID:-}" "${WEBSOCKIFY_PID:-}" "${FLUXBOX_PID:-}" "${VNC_PID:-}" "${DBUS_PID:-}" "${XRAY_PID:-}"; do
        kill_by_pid "$pid" 1
    done
fi

SERVICES=(
    "Antigravity:$APP_PATTERN"
    "websockify:websockify.*${NOVNC_PORT}"
    "Fluxbox:fluxbox"
    "Xvnc:Xvnc :${DISPLAY_NUM}"
    "DBus:dbus-daemon.*${XDG_RUNTIME_DIR}"
)

for service in "${SERVICES[@]}"; do
    kill_by_pattern "${service#*:}" 1
done

"$SCRIPT_DIR/stop-vpn.sh" >/dev/null 2>&1 || true

rm -f "$XDG_RUNTIME_DIR/bus" 2>/dev/null || true
rm -f "$PID_FILE" "$LOCK_FILE"
rm -f "$PROXY_ENV_FILE"
clear_proxy_vars

sleep 1

echo ""
echo "🔍 Verification:"

ALL_STOPPED=true
for service in "${SERVICES[@]}"; do
    name="${service%%:*}"
    pattern="${service#*:}"

    if pgrep -f "$pattern" >/dev/null 2>&1; then
        echo "   ⚠️  $name still running: $(pgrep -f "$pattern" | tr '\n' ' ')"
        ALL_STOPPED=false
    else
        echo "   ✅ $name stopped"
    fi
done

if pgrep -f "xray run" >/dev/null 2>&1; then
    echo "   ⚠️  Xray still running: $(pgrep -f "xray run" | tr '\n' ' ')"
    ALL_STOPPED=false
else
    echo "   ✅ Xray stopped"
fi

echo ""
if [ "$ALL_STOPPED" = true ]; then
    echo "✅ All services stopped successfully"
else
    echo "⚠️  Some services are still running"
fi
