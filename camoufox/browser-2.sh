#!/usr/bin/env bash
set -euo pipefail

profile_dir="${CAMOUFOX_PROFILE_2_DIR:-$HOME/.camoufox/profile-2}"
mkdir -p "$profile_dir"

echo "[camoufox-2] Opening: $*" >&2
echo "[camoufox-2] Profile: $profile_dir" >&2

exec @camoufoxBinary@ \
  --no-remote \
  --new-instance \
  --profile "$profile_dir" \
  "$@"
