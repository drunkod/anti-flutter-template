#!/usr/bin/env bash
# Creates all browser/app launcher scripts in ~/.local/bin/.
# Must run before setup_fluxbox (which renders the menu with CMD paths).

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_launchers() {
    echo "🔗 Creating app launchers..."

    # Build a safe array literal for generated launcher scripts
    local flags_array_literal
    flags_array_literal="$(printf '  %q\n' "${CHROMIUM_FLAGS[@]}")"

    # ── Chromium ──────────────────────────────────────────────────────────────
    local chromium_bin=""
    chromium_bin="$(_find_bin chromium || _find_bin chromium-browser || true)"

    if [ -n "$chromium_bin" ]; then
        mkdir -p "$(dirname "$BROWSER_CMD")"
        rm -f "$BROWSER_CMD"
        cat > "$BROWSER_CMD" <<LAUNCHER
#!/usr/bin/env bash
flags=(
$flags_array_literal
)
exec "$chromium_bin" "\${flags[@]}" "\$@"
LAUNCHER
        chmod +x "$BROWSER_CMD"

        rm -f "$BROWSER_PROXY_CMD"
        cat > "$BROWSER_PROXY_CMD" <<LAUNCHER
#!/usr/bin/env bash
flags=(
$flags_array_literal
)
exec "$chromium_bin" "\${flags[@]}" --proxy-server="socks5://127.0.0.1:$SOCKS_PORT" "\$@"
LAUNCHER
        chmod +x "$BROWSER_PROXY_CMD"
        echo "   ✅ Chromium launchers created"
    else
        echo "   ⚠️  Chromium binary not found, skipping"
    fi

    # ── Camoufox ─────────────────────────────────────────────────────────────
    local camoufox_bin=""
    camoufox_bin="$(_find_bin camoufox || true)"

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

        cat > "$CAMOUFOX_PROXY_CMD" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
profile_dir="\${CAMOUFOX_PROXY_PROFILE_DIR:-\$HOME/.camoufox/profile-proxy}"
mkdir -p "\$profile_dir"
[ "\$#" -eq 0 ] && set -- "about:blank"
exec "$camoufox_bin" -no-remote -new-instance -profile "\$profile_dir" \
    --proxy-server="socks5://127.0.0.1:$SOCKS_PORT" "\$@"
LAUNCHER
        chmod +x "$CAMOUFOX_PROXY_CMD"
        echo "   ✅ Camoufox launchers created"
    else
        echo "   ⚠️  Camoufox binary not found, skipping"
    fi

    # ── Antigravity ───────────────────────────────────────────────────────────
    local antigravity_bin=""
    antigravity_bin="$(_find_bin antigravity || true)"

    if [ -n "$antigravity_bin" ]; then
        mkdir -p "$(dirname "$ANTIGRAVITY_CMD")"
        ln -sf "$antigravity_bin" "$ANTIGRAVITY_CMD"

        cat > "$ANTIGRAVITY_PROXY_CMD" <<LAUNCHER
#!/usr/bin/env bash
exec proxychains4 -f "$PROXYCHAINS_CONF" "$antigravity_bin" "\$@"
LAUNCHER
        chmod +x "$ANTIGRAVITY_PROXY_CMD"
        echo "   ✅ Antigravity launchers created"
    else
        echo "   ⚠️  Antigravity binary not found, skipping"
    fi

    # ── WARP proxy launchers (use WARP_SOCKS_PORT) ────────────────────────────
    if [ -n "$chromium_bin" ]; then
        rm -f "$BROWSER_WARP_CMD"
        cat > "$BROWSER_WARP_CMD" <<LAUNCHER
#!/usr/bin/env bash
flags=(
$flags_array_literal
)
exec "$chromium_bin" "\${flags[@]}" --proxy-server="socks5://127.0.0.1:$WARP_SOCKS_PORT" "\$@"
LAUNCHER
        chmod +x "$BROWSER_WARP_CMD"
    fi

    if [ -n "$camoufox_bin" ]; then
        cat > "$CAMOUFOX_WARP_CMD" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail
profile_dir="\${CAMOUFOX_WARP_PROFILE_DIR:-\$HOME/.camoufox/profile-warp}"
mkdir -p "\$profile_dir"
[ "\$#" -eq 0 ] && set -- "about:blank"
exec "$camoufox_bin" -no-remote -new-instance -profile "\$profile_dir" \
    --proxy-server="socks5://127.0.0.1:$WARP_SOCKS_PORT" "\$@"
LAUNCHER
        chmod +x "$CAMOUFOX_WARP_CMD"
    fi

    if [ -n "$antigravity_bin" ]; then
        cat > "$ANTIGRAVITY_WARP_CMD" <<LAUNCHER
#!/usr/bin/env bash
exec proxychains4 -f "$PROXYCHAINS_WARP_CONF" "$antigravity_bin" "\$@"
LAUNCHER
        chmod +x "$ANTIGRAVITY_WARP_CMD"
    fi

    # Count how many WARP launchers were created
    local warp_count=0
    [ -x "${BROWSER_WARP_CMD:-}" ] && warp_count=$((warp_count + 1))
    [ -x "${CAMOUFOX_WARP_CMD:-}" ] && warp_count=$((warp_count + 1))
    [ -x "${ANTIGRAVITY_WARP_CMD:-}" ] && warp_count=$((warp_count + 1))
    if [ "$warp_count" -gt 0 ]; then
        echo "   ✅ WARP launchers created ($warp_count)"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_launchers
fi
