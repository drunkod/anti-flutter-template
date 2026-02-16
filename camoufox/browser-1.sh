#!/usr/bin/env bash
set -eo pipefail

home_dir="${HOME:-/tmp}"
profile_dir="${CAMOUFOX_PROFILE_1_DIR:-$home_dir/.camoufox/profile-1}"
log_file="${FLUXBOX_DEBUG_LOG:-$home_dir/.fluxbox-debug.log}"

mkdir -p "$profile_dir"

if [ "$#" -eq 0 ]; then
  set -- "about:blank"
fi

# IDX/containers can block Firefox sandbox/user-ns behavior.
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-0}"
export MOZ_X11_EGL="${MOZ_X11_EGL:-0}"
export MOZ_WEBRENDER="${MOZ_WEBRENDER:-0}"
export MOZ_DISABLE_CONTENT_SANDBOX="${MOZ_DISABLE_CONTENT_SANDBOX:-1}"
export MOZ_DISABLE_RDD_SANDBOX="${MOZ_DISABLE_RDD_SANDBOX:-1}"
export MOZ_DISABLE_GMP_SANDBOX="${MOZ_DISABLE_GMP_SANDBOX:-1}"
export GTK_USE_PORTAL="${GTK_USE_PORTAL:-0}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

{
  echo "$(date): [camoufox-1] DISPLAY=${DISPLAY:-<unset>} HOME=${HOME:-<unset>}"
  echo "$(date): [camoufox-1] Profile: $profile_dir"
  echo "$(date): [camoufox-1] Opening: $*"
} >> "$log_file" 2>/dev/null || true

exec @camoufoxBinary@ \
  --no-remote \
  --new-instance \
  --profile "$profile_dir" \
  "$@"
