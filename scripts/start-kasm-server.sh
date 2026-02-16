#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=./install-kasmvnc-release.sh
source "$SCRIPT_DIR/scripts/install-kasmvnc-release.sh"

start_kasm_server() {
    if ! command -v vncserver >/dev/null 2>&1; then
        log_warn "vncserver not found. Trying GitHub release installer..."
        install_kasmvnc_from_release || return 1
    fi

    if ! command -v vncserver >/dev/null 2>&1; then
        log_error "vncserver command still unavailable after install attempt"
        return 1
    fi

    echo "⚙️  Configuring KasmVNC..."
    mkdir -p "$HOME/.vnc"

    cat > "$HOME/.vnc/kasmvnc.yaml" <<EOF_CONFIG
network:
  protocol: http
  interface: 0.0.0.0
  websocket_port: ${NOVNC_PORT}
  ssl:
    require_ssl: false
EOF_CONFIG

    cat > "$HOME/.vnc/xstartup" <<'EOF_XSTARTUP'
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# Auto-launch an xterm so the user has a terminal immediately
xterm -fa "DejaVu Sans Mono" -fs 11 -bg black -fg white -geometry 100x30+50+50 &

# Start the window manager as the session root process
exec fluxbox
EOF_XSTARTUP
    chmod +x "$HOME/.vnc/xstartup"

    vncserver -kill ":$DISPLAY_NUM" >/dev/null 2>&1 || true

    echo "🚀 Starting KasmVNC server..."
    vncserver ":$DISPLAY_NUM" -geometry 1920x1080 -depth 24 -disableBasicAuth

    if ! wait_for_port "127.0.0.1" "$NOVNC_PORT" 10; then
        log_error "KasmVNC web port $NOVNC_PORT did not start listening"
        return 1
    fi

    VNC_PID="$(cat "$HOME/.vnc/"*":${DISPLAY_NUM}.pid" 2>/dev/null | head -n1 || true)"
    if [ -z "$VNC_PID" ]; then
        VNC_PID="$(pgrep -f "Xvnc :${DISPLAY_NUM}" | head -n1 || true)"
    fi

    export VNC_PID
    log_success "KasmVNC is running on port $NOVNC_PORT"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    start_kasm_server
fi
