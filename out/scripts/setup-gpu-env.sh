#!/usr/bin/env bash

set -euo pipefail

setup_gpu_env() {
    # Disable GPU/Vulkan in remote desktop sessions.
    export VK_ICD_FILENAMES=""
    export LIBVA_DRIVER_NAME=null
    export MESA_LOADER_DRIVER_OVERRIDE=swrast
    export GALLIUM_DRIVER=llvmpipe
    export __EGL_VENDOR_LIBRARY_FILENAMES=""
    export LIBGL_ALWAYS_SOFTWARE=1

    # Disable ALSA warnings in headless environment.
    export ALSA_CONFIG_PATH="/dev/null"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_gpu_env
fi
