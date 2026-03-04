#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_fonts() {
    echo "🛠️  Configuring fonts..."

    # Try nix-build approach first (works in devShells)
    if command -v nix-build >/dev/null 2>&1; then
        FONTCONFIG_FILE="$(nix-build --no-out-link -E '
with import <nixpkgs> {};
let
  userFontsDir = builtins.getEnv "HOME" + "/.local/share/fonts";
in
makeFontsConf {
  fontDirectories = [
    dejavu_fonts
    liberation_ttf
    noto-fonts
  ] ++ (if builtins.pathExists userFontsDir then [ userFontsDir ] else []);
}' 2>/dev/null || true)"

        if [ -n "$FONTCONFIG_FILE" ] && [ -f "$FONTCONFIG_FILE" ]; then
            export FONTCONFIG_FILE
            echo "   ✅ Fonts configured via nix-build"
            return 0
        fi
    fi

    # Fallback: create a simple fonts.conf using packages from dev.nix
    local fonts_conf="$HOME/.config/fontconfig/fonts.conf"
    mkdir -p "$(dirname "$fonts_conf")"

    cat > "$fonts_conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>/nix/var/nix/profiles/default/share/fonts</dir>
  <dir>~/.local/share/fonts</dir>
  <dir>~/.nix-profile/share/fonts</dir>
</fontconfig>
EOF

    export FONTCONFIG_FILE="$fonts_conf"
    echo "   ✅ Fonts configured via fallback fonts.conf"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fonts
fi
