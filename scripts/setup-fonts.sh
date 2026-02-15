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

    export FONTCONFIG_FILE
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
}')"

    if [ ! -f "$FONTCONFIG_FILE" ]; then
        log_error "Failed to create FONTCONFIG_FILE"
        return 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fonts
fi
