# VNC Desktop + VPN Environment

A standalone VNC Desktop workspace powered by Nix. Provides a full graphical environment (Fluxbox + Xterm + Chromium + Camoufox) running entirely in the browser using noVNC, with integrated Xray VPN proxy support.

## Features

- **NoVNC & Xvnc**: Lightweight web-accessible Linux desktop.
- **Fluxbox**: Fast and customizable window manager.
- **Browsers Built-in**: Chromium and Camoufox with pre-configured proxy routing.
- **Xray VPN Support**: Built-in scripts to tunnel all traffic through Xray (VMess, VLESS, Reality).
- **Project IDX / NixOS Compatible**: Uses `flake.nix` and `dev.nix` to guarantee a reproducible environment.

## Getting Started

1. Set up your environment using Nix or Project IDX.
2. Run the environment:
   ```bash
   just start
   ```
3. Open the provided `noVNC` URL in your browser.

## VPN Configuration (Optional)

To enable transparent proxied networking for your desktop:

1. Copy one of the VPN config examples:
   ```bash
   cp v2ray-client.json.example v2ray-client.json
   ```
2. Edit `v2ray-client.json` with your server details.
3. Start the environment, it will automatically connect to the VPN and route Chromium/Camoufox traffic through it.

## Browser Shortcuts in Fluxbox

- `Ctrl+Alt+B`: Launch Chromium
- `Ctrl+Alt+1`: Launch Camoufox (Profile 1)
- `Ctrl+Alt+2`: Launch Camoufox (Profile 2)
- `Ctrl+Alt+T`: Launch Terminal (XTerm)

## Service Management

You can use the included `justfile` logic or bash scripts:

```bash
just start    # Launch VNC + Fluxbox + VPN
just stop     # Stop all services
just status   # Check service status
just vpn      # Start VPN only
just vpn-stop # Stop VPN only
```
