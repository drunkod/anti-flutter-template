#!/usr/bin/env bash

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[OK] $*"
}

log_warn() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERROR] $*"
}

check_process() {
    local name="$1"
    local pattern="$2"
    local pids

    pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
    if [ -n "$pids" ]; then
        echo "✅ $name: running ($pids)"
        return 0
    fi

    echo "❌ $name: not running"
    return 1
}

kill_by_pattern() {
    local pattern="$1"
    local timeout="${2:-2}"

    pkill -15 -f "$pattern" 2>/dev/null || true
    sleep "$timeout"
    pkill -9 -f "$pattern" 2>/dev/null || true
}

kill_by_pid() {
    local pid="$1"
    local timeout="${2:-2}"

    if [ -z "$pid" ]; then
        return 0
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    kill "$pid" 2>/dev/null || true
    sleep "$timeout"
    kill -9 "$pid" 2>/dev/null || true
}

write_proxy_env() {
    local socks="$1"
    local http="$2"
    local file="$3"

    cat > "$file" <<EOF_PROXY
# Source this file to enable proxy for your shell:
#   source ~/.xray-proxy.env
export http_proxy="http://127.0.0.1:$http"
export https_proxy="http://127.0.0.1:$http"
export HTTP_PROXY="http://127.0.0.1:$http"
export HTTPS_PROXY="http://127.0.0.1:$http"
export all_proxy="socks5h://127.0.0.1:$socks"
export ALL_PROXY="socks5h://127.0.0.1:$socks"
export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export NO_PROXY="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export PROXY_SOCKS5="127.0.0.1:$socks"
export PROXY_HTTP="127.0.0.1:$http"
EOF_PROXY
}

export_proxy_vars() {
    local socks="$1"
    local http="$2"

    export http_proxy="http://127.0.0.1:$http"
    export https_proxy="http://127.0.0.1:$http"
    export HTTP_PROXY="http://127.0.0.1:$http"
    export HTTPS_PROXY="http://127.0.0.1:$http"
    export all_proxy="socks5h://127.0.0.1:$socks"
    export ALL_PROXY="socks5h://127.0.0.1:$socks"
    export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    export NO_PROXY="$no_proxy"
    export PROXY_SOCKS5="127.0.0.1:$socks"
    export PROXY_HTTP="127.0.0.1:$http"
}

clear_proxy_vars() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null || true
    unset all_proxy ALL_PROXY no_proxy NO_PROXY 2>/dev/null || true
    unset PROXY_SOCKS5 PROXY_HTTP 2>/dev/null || true
}

wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout_s="${3:-10}"
    local start

    start="$(date +%s)"
    while true; do
        if command -v nc >/dev/null 2>&1; then
            if nc -z -w 1 "$host" "$port" >/dev/null 2>&1; then
                return 0
            fi
        else
            if (echo > "/dev/tcp/$host/$port") >/dev/null 2>&1; then
                return 0
            fi
        fi

        if [ "$(( $(date +%s) - start ))" -ge "$timeout_s" ]; then
            return 1
        fi

        sleep 1
    done
}

test_vpn_connection() {
    local socks_port="$1"
    local real_ip
    local vpn_ip

    real_ip="$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
        curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "unknown")"
    vpn_ip="$(curl -s --connect-timeout 8 --proxy "socks5h://127.0.0.1:$socks_port" https://ifconfig.me 2>/dev/null || echo "failed")"

    if [ "$vpn_ip" = "failed" ]; then
        echo "   ⚠️  Could not reach internet through VPN proxy"
        return 1
    fi

    echo "   🌍 Real IP: $real_ip"
    echo "   🔒 VPN IP:  $vpn_ip"

    if [ "$real_ip" != "$vpn_ip" ]; then
        echo "   ✅ VPN is working! IPs are different."
        return 0
    fi

    echo "   ⚠️  IPs are the same — VPN may not be routing"
    return 1
}

render_template() {
    local template="$1"
    local output="$2"
    shift 2

    if [ ! -f "$template" ]; then
        log_error "Template not found: $template"
        return 1
    fi

    local content
    content="$(cat "$template")"

    local kv key value
    for kv in "$@"; do
        key="${kv%%=*}"
        value="${kv#*=}"
        content="${content//\{\{${key}\}\}/${value}}"
    done

    printf '%s\n' "$content" > "$output"
}
