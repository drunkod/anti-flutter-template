#!/usr/bin/env bash

set -euo pipefail

setup_fonts() {
    echo "🛠️  Configuring fonts..."
    local fonts_conf="$HOME/.config/fontconfig/fonts.conf"
    mkdir -p "$(dirname "$fonts_conf")"
    cat > "$fonts_conf" << 'FONTEOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>/nix/var/nix/profiles/default/share/fonts</dir>
  <dir>~/.local/share/fonts</dir>
  <dir>~/.nix-profile/share/fonts</dir>
</fontconfig>
FONTEOF
    export FONTCONFIG_FILE="$fonts_conf"
    echo "   ✅ Fonts configured"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fonts
fi
