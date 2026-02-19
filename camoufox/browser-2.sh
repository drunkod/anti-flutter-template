#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/tmp}"
profile_dir="${CAMOUFOX_PROFILE_2_DIR:-$home_dir/.camoufox/profile-2}"
log_file="${FLUXBOX_DEBUG_LOG:-$home_dir/.fluxbox-debug.log}"

mkdir -p "$profile_dir"

if [ "$#" -eq 0 ]; then
  set -- "about:blank"
fi

{
  echo "$(date): [camoufox-2] DISPLAY=${DISPLAY:-<unset>} HOME=${HOME:-<unset>}"
  echo "$(date): [camoufox-2] Profile: $profile_dir"
  echo "$(date): [camoufox-2] Opening: $*"
  echo "$(date): [camoufox-2] Binary: @camoufoxBinary@"
} >> "$log_file" 2>/dev/null || true

exec >> "$log_file" 2>&1
exec @camoufoxBinary@ \
  -no-remote \
  -new-instance \
  -profile "$profile_dir" \
  "$@"
