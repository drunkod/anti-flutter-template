#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_xdg() {
    echo "🌐 Configuring xdg-open default browser..."

    # Locate camoufox binary for .desktop file
    local camoufox_bin=""
    if command -v camoufox >/dev/null 2>&1; then
        camoufox_bin="$(command -v camoufox)"
    elif [ -x "$SCRIPT_DIR/bin/camoufox" ]; then
        camoufox_bin="$SCRIPT_DIR/bin/camoufox"
    fi

    # 1. Create .desktop files for browser launchers
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/chromium-vnc.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Chromium
Exec=$BROWSER_CMD %U
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/about;x-scheme-handler/unknown;
Terminal=false
Categories=Network;WebBrowser;
DESKTOP

    if [ -n "$camoufox_bin" ]; then
        cat > "$HOME/.local/share/applications/camoufox-vnc.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Camoufox
Exec=$CAMOUFOX_BROWSER1_CMD %U
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
Terminal=false
Categories=Network;WebBrowser;
DESKTOP
    fi

    # 2. Set Chromium as the default for URL schemes via mimeapps.list
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/mimeapps.list" <<MIME
[Default Applications]
text/html=chromium-vnc.desktop
x-scheme-handler/http=chromium-vnc.desktop
x-scheme-handler/https=chromium-vnc.desktop
x-scheme-handler/about=chromium-vnc.desktop
x-scheme-handler/unknown=chromium-vnc.desktop
MIME

    # 3. Set BROWSER env var (used by many CLI tools as fallback)
    export BROWSER="$BROWSER_CMD"

    # 4. Symlink xdg-open fallback: if xdg-utils is missing, provide a shim
    if ! command -v xdg-open >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        cat > "$HOME/.local/bin/xdg-open" <<'SHIM'
#!/usr/bin/env bash
exec "$BROWSER" "$@"
SHIM
        chmod +x "$HOME/.local/bin/xdg-open"
    fi

    echo "   ✅ xdg-open default browser set to Chromium"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_xdg
fi
