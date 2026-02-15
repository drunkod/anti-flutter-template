#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

CONFIG_ARG="${1:-}"

if [ "$CONFIG_ARG" = "reality" ]; then
    CONFIG_FILE="$SCRIPT_DIR/$VPN_REALITY_CONFIG_FILE"
elif [ -n "$CONFIG_ARG" ]; then
    CONFIG_FILE="$CONFIG_ARG"
else
    CONFIG_FILE="$SCRIPT_DIR/$VPN_CONFIG_FILE"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Config file not found: $CONFIG_FILE"

    if [ "$CONFIG_FILE" = "$SCRIPT_DIR/$VPN_CONFIG_FILE" ] && [ -f "$SCRIPT_DIR/$VPN_CONFIG_EXAMPLE_FILE" ]; then
        echo "Copy $VPN_CONFIG_EXAMPLE_FILE to $VPN_CONFIG_FILE and fill in your server details."
    elif [ "$CONFIG_FILE" = "$SCRIPT_DIR/$VPN_REALITY_CONFIG_FILE" ] && [ -f "$SCRIPT_DIR/$VPN_REALITY_CONFIG_EXAMPLE_FILE" ]; then
        echo "Copy $VPN_REALITY_CONFIG_EXAMPLE_FILE to $VPN_REALITY_CONFIG_FILE and fill in your server details."
    fi

    exit 1
fi

echo "============================================"
echo "🔐 Xray VPN Proxy"
echo "============================================"
echo "   Config: $CONFIG_FILE"
echo ""

RUNTIME_CONFIG_FILE="$CONFIG_FILE"
TEMP_CONFIG_FILE=""
cleanup_runtime_config() {
    if [ -n "$TEMP_CONFIG_FILE" ] && [ -f "$TEMP_CONFIG_FILE" ]; then
        rm -f "$TEMP_CONFIG_FILE"
    fi
}
trap cleanup_runtime_config EXIT

if grep -q "YOUR_WORKSTATION_DOMAIN" "$CONFIG_FILE"; then
    if [ -z "${WORKSTATION_DOMAIN:-}" ]; then
        log_error "WORKSTATION_DOMAIN is empty; cannot replace YOUR_WORKSTATION_DOMAIN"
        exit 1
    fi

    TEMP_CONFIG_FILE="$(mktemp)"
    escaped_domain="$(printf '%s' "$WORKSTATION_DOMAIN" | sed 's/[\\/&]/\\&/g')"
    sed "s/YOUR_WORKSTATION_DOMAIN/$escaped_domain/g" "$CONFIG_FILE" > "$TEMP_CONFIG_FILE"
    RUNTIME_CONFIG_FILE="$TEMP_CONFIG_FILE"
    log_info "Using WORKSTATION_DOMAIN=$WORKSTATION_DOMAIN for VPN routing bypass"
fi

if grep -q "YOUR_SERVER_ADDRESS\|YOUR-UUID-HERE\|YOUR_PUBLIC_KEY\|YOUR_REALITY_SNI\|YOUR_SHORT_ID\|YOUR_WORKSTATION_DOMAIN" "$RUNTIME_CONFIG_FILE"; then
    log_error "Config still has placeholder values: $CONFIG_FILE"
    exit 1
fi

if [ -f "$VPN_PID_FILE" ]; then
    OLD_PID="$(cat "$VPN_PID_FILE" 2>/dev/null || true)"
    if [ -n "$OLD_PID" ]; then
        log_info "Stopping existing Xray (PID $OLD_PID)"
        kill_by_pid "$OLD_PID" 2
    fi
fi
rm -f "$VPN_PID_FILE"

kill_by_pattern "xray run" 1

log_info "Starting Xray"
xray run -config "$RUNTIME_CONFIG_FILE" > "$VPN_LOG_FILE" 2>&1 &
XRAY_PID=$!
echo "$XRAY_PID" > "$VPN_PID_FILE"

sleep 3

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    log_error "Xray failed to start. Last log lines:"
    tail -20 "$VPN_LOG_FILE" || true
    rm -f "$VPN_PID_FILE"
    exit 1
fi

log_info "Checking proxy ports"
for port in "$SOCKS_PORT" "$HTTP_PORT"; do
    if wait_for_port "127.0.0.1" "$port" 5; then
        log_success "Port $port is listening"
    else
        log_warn "Port $port is not listening yet"
    fi
done

log_info "Testing proxy connection"
test_vpn_connection "$SOCKS_PORT" || log_warn "Proxy connectivity test failed"

write_proxy_env "$SOCKS_PORT" "$HTTP_PORT" "$PROXY_ENV_FILE"

echo ""
echo "============================================"
echo "✅ VPN Proxy is RUNNING"
echo "============================================"
echo ""
echo "   Xray PID:     $XRAY_PID"
echo "   SOCKS5 Proxy: 127.0.0.1:$SOCKS_PORT"
echo "   HTTP Proxy:   127.0.0.1:$HTTP_PORT"
echo "   Log file:     $VPN_LOG_FILE"
echo ""
echo "   To use in current shell:"
echo "     source $PROXY_ENV_FILE"
echo ""
echo "   Stop:   ./stop-vpn.sh"
echo ""

# Machine-readable status for callers
printf 'VPN_STATUS=running\n'
printf 'VPN_PID=%s\n' "$XRAY_PID"
printf 'PROXY_ENV_FILE=%s\n' "$PROXY_ENV_FILE"
