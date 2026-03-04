#!/usr/bin/env bash

set -euo pipefail

setup_fonts() {
    echo "🛠️  Configuring fonts..."
    local fonts_conf="$HOME/.config/fontconfig/fonts.conf"
    mkdir -p "$(dirname "$fonts_conf")"

    # Collect font directories: well-known profile paths + nix store discovery
    local -a font_dirs=(
        /nix/var/nix/profiles/default/share/fonts
        "$HOME/.local/share/fonts"
        "$HOME/.nix-profile/share/fonts"
        /usr/share/fonts
        /usr/local/share/fonts
    )

    # Discover nix-store font paths (packages like dejavu_fonts, noto-fonts, etc.)
    local dir
    while IFS= read -r dir; do
        [ -n "$dir" ] && font_dirs+=("$dir")
    done < <(find /nix/store -maxdepth 4 -path '*/share/fonts/*' -type d 2>/dev/null \
                | sed 's|/share/fonts/.*|/share/fonts|' | sort -u)

    # Also pick up fonts reachable through nix profile symlinks
    for dir in "$HOME/.nix-profile" /nix/var/nix/profiles/default /run/current-system/sw; do
        [ -d "$dir/share/fonts" ] && font_dirs+=("$dir/share/fonts")
    done

    # Build fonts.conf
    {
        echo '<?xml version="1.0"?>'
        echo '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">'
        echo '<fontconfig>'
        local seen="" d
        for d in "${font_dirs[@]}"; do
            # de-duplicate
            case "$seen" in *"|$d|"*) continue ;; esac
            seen="$seen|$d|"
            echo "  <dir>$d</dir>"
        done
        echo '</fontconfig>'
    } > "$fonts_conf"

    export FONTCONFIG_FILE="$fonts_conf"

    # Verify at least one font is reachable
    if command -v fc-list >/dev/null 2>&1; then
        local count
        count="$(fc-list 2>/dev/null | wc -l)"
        if [ "$count" -gt 0 ]; then
            echo "   ✅ Fonts configured ($count fonts found)"
        else
            echo "   ⚠️  fonts.conf written but fc-list found 0 fonts"
        fi
    else
        echo "   ✅ Fonts configured (fc-list not available to verify)"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fonts
fi
