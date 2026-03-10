#!/usr/bin/env bash
# WARP VPN setup and management via wgcf + wireproxy.
# Usage:
#   ./scripts/start-warp.sh          # setup + start (default)
#   ./scripts/start-warp.sh setup    # register account + generate config only
#   ./scripts/start-warp.sh start    # setup + start wireproxy
#   ./scripts/start-warp.sh stop     # stop wireproxy
#   ./scripts/start-warp.sh status   # check if running

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_warp() {
    echo "============================================"
    echo "🌐 WARP VPN Setup (wireproxy)"
    echo "============================================"

    # Check dependencies
    local wgcf_bin wireproxy_bin
    wgcf_bin="$(_find_bin wgcf || true)"
    wireproxy_bin="$(_find_bin wireproxy || true)"

    if [ -z "$wgcf_bin" ]; then
        log_error "wgcf not found in PATH or $SCRIPT_DIR/bin/"
        return 1
    fi
    if [ -z "$wireproxy_bin" ]; then
        log_error "wireproxy not found in PATH or $SCRIPT_DIR/bin/"
        return 1
    fi

    mkdir -p "$WARP_DIR"
    cd "$WARP_DIR"

    # 1. Register WARP account
    if [ ! -f wgcf-account.toml ]; then
        echo "📝 Registering WARP account..."
        "$wgcf_bin" register --accept-tos
        log_success "WARP account registered"
    else
        echo "   WARP account already exists, skipping registration."
    fi

    # 2. Generate WireGuard profile
    if [ ! -f wgcf-profile.conf ]; then
        echo "🔑 Generating WireGuard profile..."
        "$wgcf_bin" generate
        log_success "WireGuard profile generated"
    else
        echo "   WireGuard profile already exists, skipping generation."
    fi

    # 3. Create wireproxy.conf from the WireGuard profile
    if [ ! -f wireproxy.conf ]; then
        echo "⚙️  Creating wireproxy.conf..."
        cp wgcf-profile.conf wireproxy.conf
    fi

    # Append Socks5 section if not already present
    if ! grep -q '^\[Socks5\]' wireproxy.conf; then
        printf '\n[Socks5]\nBindAddress = 127.0.0.1:%s\n' "$WARP_SOCKS_PORT" >> wireproxy.conf
    fi

    echo ""
    log_success "WARP setup complete. Files:"
    ls -la "$WARP_DIR"
    echo ""
}

start_warp() {
    local wireproxy_bin
    wireproxy_bin="$(_find_bin wireproxy || true)"

    if [ -z "$wireproxy_bin" ]; then
        log_error "wireproxy not found"
        return 1
    fi

    if [ ! -f "$WARP_DIR/wireproxy.conf" ]; then
        log_error "wireproxy.conf not found in $WARP_DIR/. Run setup first."
        return 1
    fi

    # Stop existing instance
    if [ -f "$WIREPROXY_PID_FILE" ]; then
        local old_pid
        old_pid="$(cat "$WIREPROXY_PID_FILE" 2>/dev/null || true)"
        if [ -n "$old_pid" ]; then
            log_info "Stopping existing wireproxy (PID $old_pid)"
            kill_by_pid "$old_pid" 2
        fi
    fi
    rm -f "$WIREPROXY_PID_FILE"

    echo "🚀 Starting wireproxy..."
    "$wireproxy_bin" -c "$WARP_DIR/wireproxy.conf" > "$WIREPROXY_LOG_FILE" 2>&1 &
    local wpid=$!
    echo "$wpid" > "$WIREPROXY_PID_FILE"

    sleep 3

    if ! kill -0 "$wpid" 2>/dev/null; then
        log_error "wireproxy failed to start. Last log lines:"
        tail -20 "$WIREPROXY_LOG_FILE" || true
        rm -f "$WIREPROXY_PID_FILE"
        return 1
    fi

    if wait_for_port "127.0.0.1" "$WARP_SOCKS_PORT" 10; then
        log_success "WARP SOCKS5 proxy listening on 127.0.0.1:$WARP_SOCKS_PORT"
    else
        log_warn "WARP SOCKS5 port $WARP_SOCKS_PORT not listening yet"
    fi

    # Quick connectivity test
    echo ""
    echo "🌍 Testing WARP connection..."
    local warp_ip
    warp_ip="$(curl -s --connect-timeout 8 --proxy "socks5h://127.0.0.1:$WARP_SOCKS_PORT" \
        https://ifconfig.me 2>/dev/null || echo "failed")"
    if [ "$warp_ip" != "failed" ]; then
        echo "   🔒 WARP IP: $warp_ip"
    else
        log_warn "Could not reach internet through WARP proxy"
    fi

    # Write proxy env file so other scripts can source it
    cat > "$WARP_PROXY_ENV_FILE" <<WARPEOF
export WARP_SOCKS_PROXY="socks5h://127.0.0.1:$WARP_SOCKS_PORT"
export WARP_SOCKS_PORT="$WARP_SOCKS_PORT"
WARPEOF
    chmod 600 "$WARP_PROXY_ENV_FILE"

    echo ""
    echo "============================================"
    echo "✅ WARP VPN is RUNNING"
    echo "============================================"
    echo ""
    echo "   wireproxy PID: $wpid"
    echo "   SOCKS5 Proxy:  127.0.0.1:$WARP_SOCKS_PORT"
    echo "   Log file:      $WIREPROXY_LOG_FILE"
    echo "   Env file:      $WARP_PROXY_ENV_FILE"
    echo ""
    echo "   Usage:"
    echo "     curl --proxy socks5h://127.0.0.1:$WARP_SOCKS_PORT https://ifconfig.me"
    echo ""
}

stop_warp() {
    echo "🌐 Stopping WARP VPN..."

    if [ -f "$WIREPROXY_PID_FILE" ]; then
        local pid
        pid="$(cat "$WIREPROXY_PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ]; then
            log_info "Stopping wireproxy PID $pid"
            kill_by_pid "$pid" 2
        fi
    fi

    rm -f "$WIREPROXY_PID_FILE" "$WARP_PROXY_ENV_FILE"
    kill_by_pattern "wireproxy" 1

    echo ""
    echo "✅ WARP VPN stopped"
    echo ""
}

status_warp() {
    if [ -f "$WIREPROXY_PID_FILE" ]; then
        local pid
        pid="$(cat "$WIREPROXY_PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ WARP running (PID $pid, SOCKS5 on 127.0.0.1:$WARP_SOCKS_PORT)"
            echo ""
            echo "🌍 WARP Connection Test:"
            local warp_ip
            warp_ip="$(curl -s --connect-timeout 8 --proxy "socks5h://127.0.0.1:$WARP_SOCKS_PORT" \
                https://ifconfig.me 2>/dev/null || echo "failed")"
            if [ "$warp_ip" != "failed" ]; then
                echo "   🔒 WARP IP: $warp_ip"
            else
                echo "   ⚠️  Could not reach internet through WARP"
            fi
        else
            echo "❌ WARP not running (stale PID file)"
        fi
    else
        echo "❌ WARP not running"
    fi

    if [ -f "$WIREPROXY_LOG_FILE" ]; then
        echo ""
        echo "📝 Last 5 log lines:"
        tail -5 "$WIREPROXY_LOG_FILE" | sed 's/^/   /'
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "${1:-}" in
    setup)
        setup_warp
        ;;
    start)
        setup_warp
        start_warp
        ;;
    stop)
        stop_warp
        ;;
    status)
        status_warp
        ;;
    *)
        # Default: setup + start
        setup_warp
        start_warp
        ;;
esac
