#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

kasmvnc_release_api_url() {
    local tag="${KASMVNC_RELEASE_TAG:-latest}"
    if [ "$tag" = "latest" ]; then
        printf 'https://api.github.com/repos/kasmtech/KasmVNC/releases/latest\n'
    else
        printf 'https://api.github.com/repos/kasmtech/KasmVNC/releases/tags/%s\n' "$tag"
    fi
}

kasmvnc_resolve_release_tag() {
    local configured="${KASMVNC_RELEASE_TAG:-latest}"
    if [ "$configured" != "latest" ]; then
        printf '%s\n' "$configured"
        return 0
    fi

    local api_url
    api_url="$(kasmvnc_release_api_url)"
    local release_json
    release_json="$(curl -fsSL "$api_url")"

    local tag
    tag="$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
    if [ -z "$tag" ]; then
        log_error "Unable to resolve release tag from GitHub API response" >&2
        return 1
    fi

    printf '%s\n' "$tag"
}

kasmvnc_detect_pkg_type() {
    if command -v apt-get >/dev/null 2>&1; then
        printf 'deb\n'
        return 0
    fi

    if command -v dnf >/dev/null 2>&1; then
        printf 'rpm\n'
        return 0
    fi

    if command -v apk >/dev/null 2>&1; then
        printf 'apk\n'
        return 0
    fi

    return 1
}

kasmvnc_detect_distro_token() {
    if [ ! -f /etc/os-release ]; then
    log_error "/etc/os-release not found" >&2
    return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    local id="${ID:-}"
    local codename="${VERSION_CODENAME:-}"
    local version_id="${VERSION_ID:-}"

    case "$id" in
        ubuntu)
            case "$codename" in
                noble|jammy|focal)
                    printf '%s\n' "$codename"
                    return 0
                    ;;
            esac
            ;;
        debian)
            case "$codename" in
                trixie|bookworm|bullseye)
                    printf '%s\n' "$codename"
                    return 0
                    ;;
            esac
            ;;
        kali|kali-rolling)
            printf 'kali-rolling\n'
            return 0
            ;;
        fedora)
            case "${version_id%%.*}" in
                41)
                    printf 'fedora_fortyone\n'
                    return 0
                    ;;
                40)
                    printf 'fedora_forty\n'
                    return 0
                    ;;
            esac
            ;;
        ol|oracle)
            case "${version_id%%.*}" in
                8|9)
                    printf 'oracle_%s\n' "${version_id%%.*}"
                    return 0
                    ;;
            esac
            ;;
        opensuse-leap)
            printf 'opensuse_15\n'
            return 0
            ;;
        alpine)
            local major="${version_id%%.*}"
            local rest="${version_id#*.}"
            local minor="${rest%%.*}"
            if [ "$major" = "3" ] && [ -n "$minor" ]; then
                printf 'alpine_3%s\n' "$minor"
                return 0
            fi
            ;;
    esac

    log_error "Unsupported distro for auto selection: ID=${id:-unknown} VERSION_CODENAME=${codename:-unknown} VERSION_ID=${version_id:-unknown}" >&2
    log_info "Set KASMVNC_DISTRO_TOKEN manually (examples: noble, jammy, bookworm, kali-rolling, oracle_8, fedora_fortyone, alpine_320)" >&2
    return 1
}

kasmvnc_detect_arch_token() {
    local pkg_type="$1"
    local arch

    arch="$(uname -m)"
    case "$pkg_type:$arch" in
        deb:x86_64|deb:amd64)
            printf 'amd64\n'
            return 0
            ;;
        deb:aarch64|deb:arm64)
            printf 'arm64\n'
            return 0
            ;;
        rpm:x86_64|apk:x86_64|rpm:amd64|apk:amd64)
            printf 'x86_64\n'
            return 0
            ;;
        rpm:aarch64|apk:aarch64|rpm:arm64|apk:arm64)
            printf 'aarch64\n'
            return 0
            ;;
    esac

    log_error "Unsupported architecture: $(uname -m)" >&2
    return 1
}

kasmvnc_install_source_tarball() {
    local tag="${KASMVNC_SOURCE_TAG:-}"
    if [ -z "$tag" ]; then
        if ! tag="$(kasmvnc_resolve_release_tag)"; then
            return 1
        fi
    fi

    local source_url="${KASMVNC_SOURCE_TARBALL_URL:-https://github.com/kasmtech/KasmVNC/archive/refs/tags/${tag}.tar.gz}"
    local cache_dir="${KASMVNC_DOWNLOAD_DIR:-$HOME/.cache/kasmvnc}"
    local src_dir="$cache_dir/source"
    local extract_dir="$src_dir/KasmVNC-${tag#v}"
    local tarball_path="$src_dir/kasmvnc-${tag}.tar.gz"

    mkdir -p "$src_dir"
    if [ ! -f "$tarball_path" ]; then
        log_info "Downloading source tarball: $source_url"
        curl -fL "$source_url" -o "$tarball_path"
    fi

    if [ ! -d "$extract_dir" ]; then
        mkdir -p "$src_dir/extract"
        tar -xzf "$tarball_path" -C "$src_dir/extract"
        if [ -d "$src_dir/extract/KasmVNC-${tag#v}" ]; then
            mv "$src_dir/extract/KasmVNC-${tag#v}" "$extract_dir"
        else
            local extracted_top
            extracted_top="$(find "$src_dir/extract" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
            if [ -z "$extracted_top" ]; then
                log_error "Unable to find extracted source directory"
                return 1
            fi
            mv "$extracted_top" "$extract_dir"
        fi
        rmdir "$src_dir/extract" 2>/dev/null || true
    fi

    if ! command -v docker >/dev/null 2>&1; then
        log_error "No package manager found and docker is not available for source build fallback"
        log_info "This source fallback uses upstream builder scripts (requires Docker CE): $extract_dir/builder/README.md"
        return 1
    fi

    local build_os="${KASMVNC_BUILD_OS:-ubuntu}"
    local build_codename="${KASMVNC_BUILD_CODENAME:-noble}"
    local build_tag="${KASMVNC_BUILD_TAG:-}"
    local install_prefix="${KASMVNC_SOURCE_PREFIX:-$HOME/.local/kasmvnc}"
    local user_bin="$HOME/.local/bin"

    log_info "Building KasmVNC from source via Docker builder: os=$build_os codename=$build_codename tag=${build_tag:-<none>}"
    (
        cd "$extract_dir"
        ./builder/build-tarball "$build_os" "$build_codename" "$build_tag"
    )

    local tarball_name="kasmvnc.${build_os}_${build_codename}${build_tag}.tar.gz"
    local built_tarball="$extract_dir/builder/build/$tarball_name"
    if [ ! -f "$built_tarball" ]; then
        log_error "Expected built tarball not found: $built_tarball"
        return 1
    fi

    mkdir -p "$install_prefix" "$user_bin"
    tar -xzf "$built_tarball" --strip-components=1 -C "$install_prefix"

    local cmd
    for cmd in vncserver vncpasswd Xvnc; do
        if [ -x "$install_prefix/usr/bin/$cmd" ]; then
            ln -sf "$install_prefix/usr/bin/$cmd" "$user_bin/$cmd"
        elif [ -x "$install_prefix/bin/$cmd" ]; then
            ln -sf "$install_prefix/bin/$cmd" "$user_bin/$cmd"
        fi
    done

    if [ -x "$user_bin/vncserver" ]; then
        log_success "KasmVNC source fallback installed under $install_prefix"
        log_info "Ensure '$user_bin' is in PATH for this shell/session"
        return 0
    fi

    log_error "Source build finished but vncserver symlink was not created"
    return 1
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return $?
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
        return $?
    fi

    if command -v doas >/dev/null 2>&1; then
        doas "$@"
        return $?
    fi

    log_error "Root privileges required for install, but neither sudo nor doas was found"
    return 1
}

kasmvnc_add_cert_group() {
    local pkg_type="$1"

    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi

    if [ "$pkg_type" = "deb" ]; then
        if command -v adduser >/dev/null 2>&1; then
            run_as_root adduser "$USER" ssl-cert >/dev/null 2>&1 || true
        else
            run_as_root usermod -a -G ssl-cert "$USER" >/dev/null 2>&1 || true
        fi
        log_info "Added $USER to ssl-cert (reconnect shell/session for group change)"
        return 0
    fi

    run_as_root usermod -a -G kasmvnc-cert "$USER" >/dev/null 2>&1 || true
    log_info "Added $USER to kasmvnc-cert (reconnect shell/session for group change)"
}

install_kasmvnc_from_release() {
    if command -v vncserver >/dev/null 2>&1; then
        log_info "vncserver already available: $(command -v vncserver)"
        return 0
    fi

    local pkg_type
    if ! pkg_type="$(kasmvnc_detect_pkg_type)"; then
        log_warn "No native package manager detected; trying source tarball fallback"
        kasmvnc_install_source_tarball
        return $?
    fi

    local distro_token="${KASMVNC_DISTRO_TOKEN:-}"
    if [ -z "$distro_token" ]; then
        if ! distro_token="$(kasmvnc_detect_distro_token)"; then
            return 1
        fi
    fi

    local arch_token
    if ! arch_token="$(kasmvnc_detect_arch_token "$pkg_type")"; then
        return 1
    fi

    local api_url
    api_url="$(kasmvnc_release_api_url)"

    log_info "Fetching release metadata: $api_url"
    local release_json
    release_json="$(curl -fsSL "$api_url")"

    local tag
    if ! tag="$(kasmvnc_resolve_release_tag)"; then
        return 1
    fi

    local version="${tag#v}"
    local asset_name="kasmvncserver_${distro_token}_${version}_${arch_token}.${pkg_type}"

    if ! printf '%s\n' "$release_json" | rg -q "\"name\"[[:space:]]*:[[:space:]]*\"${asset_name}\""; then
        log_error "Release asset not found: $asset_name"
        log_info "Available assets for .$pkg_type:"
        printf '%s\n' "$release_json" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | rg "^kasmvncserver_.*\\.${pkg_type}$" | rg -v '^kasmvncserver_doc_' || true
        return 1
    fi

    local download_url="https://github.com/kasmtech/KasmVNC/releases/download/${tag}/${asset_name}"
    local cache_dir="${KASMVNC_DOWNLOAD_DIR:-$HOME/.cache/kasmvnc}"
    mkdir -p "$cache_dir"

    local pkg_path="$cache_dir/$asset_name"
    log_info "Downloading: $download_url"
    curl -fL "$download_url" -o "$pkg_path"

    case "$pkg_type" in
        deb)
            run_as_root apt-get install -y "$pkg_path"
            ;;
        rpm)
            run_as_root dnf localinstall -y "$pkg_path"
            ;;
        apk)
            if command -v apk >/dev/null 2>&1; then
                run_as_root apk add "$pkg_path" --allow-untrusted
            else
                log_error "apk command not found"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported package type: $pkg_type"
            return 1
            ;;
    esac

    kasmvnc_add_cert_group "$pkg_type"

    if command -v vncserver >/dev/null 2>&1; then
        log_success "KasmVNC installed successfully from GitHub release: $tag"
        log_info "You may need to reconnect shell/session before starting vncserver"
        return 0
    fi

    log_error "Install finished but vncserver is still not in PATH"
    return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_kasmvnc_from_release
fi
