#!/usr/bin/env bash

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo "[INFO] $*"; }
log_success() { echo "[OK] $*"; }
log_warn()    { echo "[WARN] $*"; }
log_error()   { echo "[ERROR] $*"; }

# ── Process helpers ───────────────────────────────────────────────────────────
check_process() {
    local name="$1" pattern="$2" pids
    pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
    if [ -n "$pids" ]; then
        echo "✅ $name: running ($pids)"; return 0
    fi
    echo "❌ $name: not running"; return 1
}

kill_by_pattern() {
    local pattern="$1" timeout="${2:-2}"
    pkill -15 -f "$pattern" 2>/dev/null || true
    sleep "$timeout"
    pkill -9  -f "$pattern" 2>/dev/null || true
}

kill_by_pid() {
    local pid="$1" timeout="${2:-2}"
    [ -n "$pid" ] || return 0
    kill -0 "$pid" 2>/dev/null || return 0
    kill    "$pid" 2>/dev/null || true
    sleep "$timeout"
    kill -9 "$pid" 2>/dev/null || true
}

# ── Proxy helpers ─────────────────────────────────────────────────────────────
# export_proxy_vars SOCKS_PORT HTTP_PORT [FILE]
# Sets proxy env vars in the current shell.
# If FILE is provided, also writes a sourceable env file for new shells.
export_proxy_vars() {
    local socks="$1"
    local http="$2"
    local file="${3:-}"
    local no_proxy_hosts="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16${WORKSTATION_DOMAIN:+,$WORKSTATION_DOMAIN}"

    export http_proxy="http://127.0.0.1:$http"
    export https_proxy="http://127.0.0.1:$http"
    export HTTP_PROXY="http://127.0.0.1:$http"
    export HTTPS_PROXY="http://127.0.0.1:$http"
    export all_proxy="socks5h://127.0.0.1:$socks"
    export ALL_PROXY="socks5h://127.0.0.1:$socks"
    export no_proxy="$no_proxy_hosts"
    export NO_PROXY="$no_proxy_hosts"
    export PROXY_SOCKS5="127.0.0.1:$socks"
    export PROXY_HTTP="127.0.0.1:$http"

    if [ -n "$file" ]; then
        cat > "$file" <<EOF_PROXY
# Source this file to enable proxy for your shell:
#   source $file
export http_proxy="http://127.0.0.1:$http"
export https_proxy="http://127.0.0.1:$http"
export HTTP_PROXY="http://127.0.0.1:$http"
export HTTPS_PROXY="http://127.0.0.1:$http"
export all_proxy="socks5h://127.0.0.1:$socks"
export ALL_PROXY="socks5h://127.0.0.1:$socks"
export no_proxy="$no_proxy_hosts"
export NO_PROXY="$no_proxy_hosts"
export PROXY_SOCKS5="127.0.0.1:$socks"
export PROXY_HTTP="127.0.0.1:$http"
EOF_PROXY
    fi
}

clear_proxy_vars() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null || true
    unset all_proxy ALL_PROXY no_proxy NO_PROXY          2>/dev/null || true
    unset PROXY_SOCKS5 PROXY_HTTP                        2>/dev/null || true
}

# ── Network helpers ───────────────────────────────────────────────────────────
wait_for_port() {
    local host="$1" port="$2" timeout_s="${3:-10}" start
    start="$(date +%s)"
    while true; do
        if command -v nc >/dev/null 2>&1; then
            nc -z -w 1 "$host" "$port" >/dev/null 2>&1 && return 0
        else
            (echo > "/dev/tcp/$host/$port") >/dev/null 2>&1 && return 0
        fi
        [ "$(( $(date +%s) - start ))" -ge "$timeout_s" ] && return 1
        sleep 1
    done
}

test_vpn_connection() {
    local socks_port="$1" real_ip vpn_ip
    real_ip="$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
        curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "unknown")"
    vpn_ip="$(curl -s --connect-timeout 8 --proxy "socks5h://127.0.0.1:$socks_port" \
        https://ifconfig.me 2>/dev/null || echo "failed")"
    if [ "$vpn_ip" = "failed" ]; then
        echo "   ⚠️  Could not reach internet through VPN proxy"; return 1
    fi
    echo "   🌍 Real IP: $real_ip"
    echo "   🔒 VPN IP:  $vpn_ip"
    if [ "$real_ip" != "$vpn_ip" ]; then
        echo "   ✅ VPN is working! IPs are different."; return 0
    fi
    echo "   ⚠️  IPs are the same — VPN may not be routing"; return 1
}

# ── Binary helpers ────────────────────────────────────────────────────────────
# _find_bin NAME
# Prints the absolute path to NAME if found in PATH or $SCRIPT_DIR/bin/.
_find_bin() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        command -v "$name"; return 0
    elif [ -x "${SCRIPT_DIR:-}/bin/$name" ]; then
        echo "$SCRIPT_DIR/bin/$name"; return 0
    fi
    return 1
}

# ensure_launcher TARGET CMD [CMD ...]
# Creates a symlink at TARGET for the first CMD found in PATH or $SCRIPT_DIR/bin/.
ensure_launcher() {
    local target="$1"; shift
    local cmd bin
    for cmd in "$@"; do
        if bin="$(_find_bin "$cmd")"; then
            mkdir -p "$(dirname "$target")"
            ln -sf "$bin" "$target"
            return 0
        fi
    done
    echo "⚠️  Could not find any of: $* for $target"; return 1
}

# ── Template rendering ────────────────────────────────────────────────────────
# render_template TEMPLATE OUTPUT KEY=VALUE [KEY=VALUE ...]
render_template() {
    local template="$1" output="$2"; shift 2
    [ -f "$template" ] || { log_error "Template not found: $template"; return 1; }
    local content kv key value
    content="$(cat "$template")"
    for kv in "$@"; do
        key="${kv%%=*}"; value="${kv#*=}"
        content="${content//\{\{${key}\}\}/${value}}"
    done
    printf '%s\n' "$content" > "$output"
}

# ── Host detection (used by config.env) ───────────────────────────────────────
_extract_host_from_value() {
    local value="$1"
    value="${value#http://}"; value="${value#https://}"
    value="${value%%/*}";     value="${value%%:*}"
    [[ "$value" =~ ^[0-9]+-(.+)$ ]] && value="${BASH_REMATCH[1]}"
    printf '%s' "$value"
}

_detect_workstation_host() {
    local candidate
    for candidate in \
            "${CLOUD_WORKSTATION_HOST:-}"     \
            "${CLOUD_WORKSTATION_FQDN:-}"     \
            "${CLOUD_WORKSTATION_HOSTNAME:-}" \
            "${CLOUD_WORKSTATION_URL:-}"      \
            "${WORKSTATION_HOST:-}"           \
            "${HOSTNAME:-}"; do
        [ -n "$candidate" ] || continue
        candidate="$(_extract_host_from_value "$candidate")"
        if [ -n "$candidate" ] && [[ "$candidate" == *".cloudworkstations.dev" ]]; then
            printf '%s' "$candidate"; return 0
        fi
    done
    return 1
}
