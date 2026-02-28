# Outputs (set as global variables after calling start_vnc_server):
#   VNC_PID, FLUXBOX_PID, WEBSOCKIFY_PID
#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

start_vnc_server() {
    if [ ! -d "$HOME/noVNC" ]; then
        echo "📦 Cloning noVNC..."
        env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
            timeout 60s git clone --depth 1 https://github.com/novnc/noVNC.git "$HOME/noVNC"
    fi

    echo "🚀 Starting VNC server..."
    Xvnc ":$DISPLAY_NUM" -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport "$VNC_PORT" -dpi 96 2>&1 &
    VNC_PID=$!
    sleep 2

    if ! kill -0 "$VNC_PID" 2>/dev/null; then
        log_error "Xvnc process exited early"
        return 1
    fi

    if ! wait_for_port "127.0.0.1" "$VNC_PORT" 10; then
        log_error "VNC port $VNC_PORT did not start listening"
        return 1
    fi

    if [ -f "$HOME/.Xresources" ]; then
        DISPLAY=":$DISPLAY_NUM" xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
    fi

    local fluxbox_shell
    fluxbox_shell="${SHELL:-}"
    if [ -z "$fluxbox_shell" ] || [ ! -x "$fluxbox_shell" ]; then
        fluxbox_shell="$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "/bin/sh")"
    fi
    if [ ! -x "$fluxbox_shell" ]; then
        log_warn "Fluxbox shell is not executable: $fluxbox_shell"
    fi
    export SHELL="$fluxbox_shell"

    echo "🖥️  Starting Fluxbox..."
    DISPLAY=":$DISPLAY_NUM" SHELL="$fluxbox_shell" fluxbox 2>/dev/null &
    FLUXBOX_PID=$!
    sleep 2

    if ! kill -0 "$FLUXBOX_PID" 2>/dev/null; then
        log_error "Fluxbox failed to start"
        return 1
    fi

    # Auto-launch an xterm so the user has a terminal immediately
    echo "📟 Auto-launching XTerm..."
    DISPLAY=":$DISPLAY_NUM" xterm -fa "DejaVu Sans Mono" -fs 11 -bg black -fg white -geometry 100x30+50+50 &
    XTERM_PID=$!
    sleep 1
    if kill -0 "$XTERM_PID" 2>/dev/null; then
        echo "   ✅ XTerm launched (PID $XTERM_PID)"
    else
        echo "   ⚠️  XTerm failed to launch"
    fi

    echo "🌐 Starting noVNC proxy..."
    websockify --web="$HOME/noVNC" "$NOVNC_PORT" "localhost:$VNC_PORT" 2>&1 &
    WEBSOCKIFY_PID=$!
    sleep 2

    if ! kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then
        log_error "websockify failed to start"
        return 1
    fi

    if ! wait_for_port "127.0.0.1" "$NOVNC_PORT" 10; then
        log_error "noVNC port $NOVNC_PORT did not start listening"
        return 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    start_vnc_server
fi
