#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_dbus() {
    echo "🔌 Starting DBus session..."

    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    rm -f "$XDG_RUNTIME_DIR/bus" || true

    export DBUS_MACHINE_UUID_FILE="$XDG_RUNTIME_DIR/machine-id"
    dbus-uuidgen --ensure="$DBUS_MACHINE_UUID_FILE" >/dev/null

    local dbus_daemon
    local dbus_prefix
    local dbus_session_conf

    dbus_daemon="$(command -v dbus-daemon)"
    dbus_prefix="$(dirname "$(dirname "$(readlink -f "$dbus_daemon")")")"
    dbus_session_conf="$dbus_prefix/share/dbus-1/session.conf"

    DBUS_PID=""
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        mapfile -t _dbus_out < <(
            dbus-daemon \
                --config-file="$dbus_session_conf" \
                --address="unix:path=$XDG_RUNTIME_DIR/bus" \
                --fork --print-address=1 --print-pid=1
        )

        export DBUS_SESSION_BUS_ADDRESS="${_dbus_out[0]}"
        DBUS_PID="${_dbus_out[1]}"
        echo "   DBus started (PID $DBUS_PID)"
    else
        echo "   DBus already running"
    fi

    export DBUS_SYSTEM_BUS_ADDRESS=""
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_dbus
fi
