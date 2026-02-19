#!/usr/bin/env bash
set -e
CALLING_USER=${SUDO_USER:-$(whoami)}

# Get the home directory for the calling user.
USER_HOME=$(eval echo "~$CALLING_USER")

echo "---"
echo "Running script for user: $CALLING_USER"
echo "Using home directory:    $USER_HOME"
echo "---"

echo "Setting up Cargo to use /tmp..."
echo ""

export CARGO_HOME=/tmp/cargo-home
export CARGO_TARGET_DIR=/tmp/cargo-target

mkdir -p "$CARGO_HOME"
mkdir -p "$CARGO_TARGET_DIR"

cat > "$CARGO_HOME/config.toml" <<'CONFIG_EOF'
[build]
target-dir = "/tmp/cargo-target"
incremental = true

[net]
git-fetch-with-cli = true
offline = false

[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
strip = true
CONFIG_EOF

echo "Cargo configured to use /tmp"
echo ""
echo "Environment variables to add to your shell:"
echo "  export CARGO_HOME=/tmp/cargo-home"
echo "  export CARGO_TARGET_DIR=/tmp/cargo-target"
echo ""
echo "Configuration saved to: $CARGO_HOME/config.toml"
