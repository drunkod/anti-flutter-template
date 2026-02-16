#!/usr/bin/env bash
set -euo pipefail

profile_dir="${CAMOUFOX_PROFILE_1_DIR:-$HOME/.camoufox/profile-1}"
mkdir -p "$profile_dir"

echo "[camoufox-1] Opening: $*" >&2
echo "[camoufox-1] Profile: $profile_dir" >&2

exec @camoufoxBinary@ \
  --no-remote \
  --new-instance \
  --profile "$profile_dir" \
  "$@"
