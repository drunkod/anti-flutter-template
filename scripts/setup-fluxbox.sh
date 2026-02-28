#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

ensure_launcher() {
    local target="$1"
    shift
    local cmd
    local found=false

    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            mkdir -p "$(dirname "$target")"
            ln -sf "$(command -v "$cmd")" "$target"
            found=true
            break
        elif [ -x "$SCRIPT_DIR/bin/$cmd" ]; then
            mkdir -p "$(dirname "$target")"
            ln -sf "$SCRIPT_DIR/bin/$cmd" "$target"
            found=true
            break
        fi
    done

    if [ "$found" = false ]; then
        echo "⚠️  Could not find any of: $* for $target"
        return 1
    fi
}

setup_fluxbox() {
    echo "🖥️  Configuring Fluxbox..."
    mkdir -p "$HOME/.fluxbox"

    TERMINAL_BIN="$(command -v xterm 2>/dev/null || echo "xterm")"
    SHELL_BIN="$(command -v bash 2>/dev/null || echo "/bin/sh")"

    ensure_launcher "$BROWSER_CMD" google-chrome chromium chromium-browser xdg-open || true

    # Create camoufox launcher scripts that point to the actual binary.
    # The binary is either in PATH or at $SCRIPT_DIR/bin/camoufox.
    local camoufox_bin=""
    if command -v camoufox >/dev/null 2>&1; then
        camoufox_bin="$(command -v camoufox)"
    elif [ -x "$SCRIPT_DIR/bin/camoufox" ]; then
        camoufox_bin="$SCRIPT_DIR/bin/camoufox"
    fi

    if [ -n "$camoufox_bin" ]; then
        mkdir -p "$(dirname "$CAMOUFOX_BROWSER1_CMD")"

        cat > "$CAMOUFOX_BROWSER1_CMD" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
profile_dir="\${CAMOUFOX_PROFILE_1_DIR:-\$HOME/.camoufox/profile-1}"
mkdir -p "\$profile_dir"
[ "\$#" -eq 0 ] && set -- "about:blank"
exec "$camoufox_bin" -no-remote -new-instance -profile "\$profile_dir" "\$@"
LAUNCHER
        chmod +x "$CAMOUFOX_BROWSER1_CMD"

        cat > "$CAMOUFOX_BROWSER2_CMD" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
profile_dir="\${CAMOUFOX_PROFILE_2_DIR:-\$HOME/.camoufox/profile-2}"
mkdir -p "\$profile_dir"
[ "\$#" -eq 0 ] && set -- "about:blank"
exec "$camoufox_bin" -no-remote -new-instance -profile "\$profile_dir" "\$@"
LAUNCHER
        chmod +x "$CAMOUFOX_BROWSER2_CMD"
        echo "   ✅ Camoufox launchers created → $camoufox_bin"
    else
        echo "   ⚠️  Camoufox binary not found, skipping launcher setup"
    fi

    # Create proxy-wrapped launcher for Chromium
    local browser_bin=""
    if [ -x "$BROWSER_CMD" ]; then
        browser_bin="$BROWSER_CMD"
    elif command -v chromium >/dev/null 2>&1; then
        browser_bin="$(command -v chromium)"
    elif [ -x "$SCRIPT_DIR/bin/chromium" ]; then
        browser_bin="$SCRIPT_DIR/bin/chromium"
    fi

    if [ -n "$browser_bin" ]; then
        cat > "$BROWSER_PROXY_CMD" <<LAUNCHER
#!/usr/bin/env bash
exec "$browser_bin" --proxy-server="socks5://127.0.0.1:$SOCKS_PORT" "\$@"
LAUNCHER
        chmod +x "$BROWSER_PROXY_CMD"
        echo "   ✅ Chromium proxy launcher created"
    fi

    # Create proxy-wrapped launcher for Camoufox
    if [ -n "$camoufox_bin" ]; then
        cat > "$CAMOUFOX_PROXY_CMD" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
profile_dir="\${CAMOUFOX_PROXY_PROFILE_DIR:-\$HOME/.camoufox/profile-proxy}"
mkdir -p "\$profile_dir"
[ "\$#" -eq 0 ] && set -- "about:blank"
exec "$camoufox_bin" -no-remote -new-instance -profile "\$profile_dir" "\$@"
LAUNCHER
        chmod +x "$CAMOUFOX_PROXY_CMD"
        echo "   ✅ Camoufox proxy launcher created"
    fi

    render_template \
        "$SCRIPT_DIR/config/fluxbox/menu.template" \
        "$HOME/.fluxbox/menu" \
        "BROWSER_CMD=$BROWSER_CMD" \
        "BROWSER_PROXY_CMD=$BROWSER_PROXY_CMD" \
        "CAMOUFOX_BROWSER1_CMD=$CAMOUFOX_BROWSER1_CMD" \
        "CAMOUFOX_BROWSER2_CMD=$CAMOUFOX_BROWSER2_CMD" \
        "CAMOUFOX_PROXY_CMD=$CAMOUFOX_PROXY_CMD" \
        "SCRIPT_DIR=$SCRIPT_DIR" \
        "SOCKS_PORT=$SOCKS_PORT" \
        "VPN_LOG_FILE=$VPN_LOG_FILE" \
        "LOG_FILE=$LOG_FILE"

    render_template \
        "$SCRIPT_DIR/config/fluxbox/keys.template" \
        "$HOME/.fluxbox/keys" \
        "BROWSER_CMD=$BROWSER_CMD" \
        "CAMOUFOX_BROWSER1_CMD=$CAMOUFOX_BROWSER1_CMD" \
        "CAMOUFOX_BROWSER2_CMD=$CAMOUFOX_BROWSER2_CMD"

    # init is static — just copy it
    cp "$SCRIPT_DIR/config/fluxbox/init" "$HOME/.fluxbox/init"

    # startup script
    install -m 755 "$SCRIPT_DIR/config/fluxbox/startup" "$HOME/.fluxbox/startup"

    # Xresources
    cp "$SCRIPT_DIR/config/Xresources" "$HOME/.Xresources"

    # Proxychains
    render_template \
        "$SCRIPT_DIR/config/proxychains.conf.template" \
        "$PROXYCHAINS_CONF" \
        "SOCKS_PORT=$SOCKS_PORT"

    echo "   ✅ Fluxbox menu, keys, and theme configured"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fluxbox
fi
