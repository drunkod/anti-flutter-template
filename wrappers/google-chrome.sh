#!/usr/bin/env bash
echo "[google-chrome] Opening: $@" >&2

proxy_args=()
if [ -n "${PROXY_SOCKS5:-}" ]; then
  proxy_args+=( "--proxy-server=socks5://${PROXY_SOCKS5}" )
  echo "[google-chrome] Using VPN proxy: socks5://${PROXY_SOCKS5}" >&2
elif [ -n "${ALL_PROXY:-}" ]; then
  proxy_args+=( "--proxy-server=${ALL_PROXY}" )
  echo "[google-chrome] Using proxy: ${ALL_PROXY}" >&2
fi

exec @chromium@ \
  @chromiumFlags@ \
  "${proxy_args[@]}" \
  "$@"
