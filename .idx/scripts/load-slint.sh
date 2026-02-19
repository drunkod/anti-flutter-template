#!/usr/bin/env bash
# Load Slint Android development environment

echo "Loading Slint Android development tools..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export SLINT_ANDROID_LOADED=1

echo "Slint Android environment loaded"
echo ""
echo "Available packages:"
echo "  Rust toolchain with Android targets"
echo "  Android SDK and NDK"
echo "  cargo-apk"
echo "  slint-android-* scripts"
echo ""
echo "Run 'slint-android-info' for detailed information"
