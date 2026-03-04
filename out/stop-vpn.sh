#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "🔐 Stopping Xray VPN Proxy..."

if [ -f "$VPN_PID_FILE" ]; then
    XRAY_PID="$(cat "$VPN_PID_FILE" 2>/dev/null || true)"
    if [ -n "$XRAY_PID" ]; then
        log_info "Stopping Xray PID $XRAY_PID"
        kill_by_pid "$XRAY_PID" 2
    else
        log_warn "Empty PID file: $VPN_PID_FILE"
    fi
else
    log_info "No VPN PID file found"
fi

rm -f "$VPN_PID_FILE"
kill_by_pattern "xray run" 1

rm -f "$PROXY_ENV_FILE"
clear_proxy_vars

echo ""
echo "✅ VPN Proxy stopped"
echo ""
