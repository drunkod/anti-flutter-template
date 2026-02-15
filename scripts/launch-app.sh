#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

launch_app() {
    echo "🚀 Launching Antigravity..."
    echo "   Logging to: $LOG_FILE"

    kill_by_pattern "$APP_PATTERN" 1

    DISPLAY=":$DISPLAY_NUM" "$SCRIPT_DIR/result/bin/antigravity" --verbose 2>&1 | \
        sed '/Failed to connect to the bus/d;/ALSA lib/d;/PcmOpen/d' > "$LOG_FILE" &

    APP_PID=$!
    echo "$APP_PID" > "$LOCK_FILE"

    sleep 3

    if ! kill -0 "$APP_PID" 2>/dev/null; then
        echo "   ❌ Antigravity crashed! Check log:"
        tail -20 "$LOG_FILE" || true
        rm -f "$LOCK_FILE"
        return 1
    fi

    ANTIGRAVITY_COUNT="$(pgrep -fc "$APP_PATTERN" 2>/dev/null || echo "0")"
    echo "   ✅ Antigravity started (main PID $APP_PID)"
    echo "   📊 Electron processes: $ANTIGRAVITY_COUNT"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    launch_app
fi
