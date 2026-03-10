# Architecture Overview

A **Firebase Studio template** that presents itself as a Flutter project creator but actually bootstraps a full **Linux VNC desktop** (Fluxbox + Chromium + Camoufox + Xterm) with optional Xray VPN — all running inside a browser tab via noVNC.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Firebase Studio (Cloud VM)                      │
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────────────────┐ │
│  │ idx-template  │    │  idx-template │    │  out/.idx/dev.nix     │ │
│  │   .json       │───▶│    .nix       │───▶│  (workspace runtime)  │ │
│  │ (UI params)   │    │ (bootstrap)   │    │                       │ │
│  └──────────────┘    └──────────────┘    └───────────────────────┘ │
│                                                    │                │
│                            ┌───────────────────────┘                │
│                            ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              start-with-vnc.sh (orchestrator)                │   │
│  │                                                              │   │
│  │  ┌───────────┐ ┌──────────┐ ┌────────────┐ ┌─────────────┐ │   │
│  │  │ Xvnc :99  │ │ Fluxbox  │ │ websockify │ │ Xray VPN    │ │   │
│  │  │ (X server)│ │ (WM)     │ │ (noVNC)    │ │ (optional)  │ │   │
│  │  └─────┬─────┘ └────┬─────┘ └──────┬─────┘ └──────┬──────┘ │   │
│  │        │             │              │               │        │   │
│  │        └──────┬──────┘              │               │        │   │
│  │               ▼                     │               │        │   │
│  │  ┌──────────────────────┐           │               │        │   │
│  │  │  Desktop Apps        │           │               │        │   │
│  │  │  • Chromium          │◀──proxy───┘               │        │   │
│  │  │  • Camoufox #1 / #2 │◀──────────proxy───────────┘        │   │
│  │  │  • Antigravity       │                                    │   │
│  │  │  • XTerm             │                                    │   │
│  │  └──────────────────────┘                                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                            │                                        │
│                            ▼                                        │
│               Firebase Studio Preview Panel                         │
│              (noVNC web client in iframe)                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
anti-flutter-template/
├── idx-template.json          # Firebase Studio UI — fake Flutter params
├── idx-template.nix           # Bootstrap — copies VNC env into $out
├── flake.nix                  # Runtime Nix flake — builds browser wrappers
├── README.md                  # User-facing readme
├── explore.md                 # Dev notes
│
├── camoufox/                  # Anti-detect browser sub-flake
│   ├── flake.nix              # Standalone flake (imported by root flake)
│   ├── package.nix            # Nix derivation: fetch, patch, wrap Camoufox
│   ├── browser-1.sh           # Wrapper template for profile #1
│   ├── browser-2.sh           # Wrapper template for profile #2
│   └── README.md
│
└── out/                       # Files copied verbatim into the workspace
    ├── .idx/
    │   └── dev.nix            # Workspace environment (packages, preview, hooks)
    ├── config.env             # All ports, paths, flags — single source of truth
    ├── lib.sh                 # Shared bash helpers (logging, process, proxy, template)
    ├── justfile               # Task runner (start/stop/status/vpn)
    │
    ├── start-with-vnc.sh      # Main orchestrator — launches everything
    ├── start-vpn.sh           # Xray VPN launcher
    ├── stop-vnc.sh            # Graceful shutdown of all services
    ├── stop-vpn.sh            # Xray-only shutdown
    ├── status-vnc.sh          # Prints process/VPN/port status
    │
    ├── scripts/               # Modular setup functions (sourced, not exec'd)
    │   ├── setup-fonts.sh     # Discovers Nix store fonts, writes fontconfig
    │   ├── setup-dbus.sh      # Starts session DBus daemon
    │   ├── setup-gpu-env.sh   # Forces software rendering (no GPU)
    │   ├── setup-launchers.sh # Generates ~/.local/bin/ browser scripts
    │   ├── setup-fluxbox.sh   # Renders menu/keys/proxychains from templates
    │   ├── setup-xdg.sh       # Sets default browser via .desktop + mimeapps
    │   └── start-vnc-server.sh# Launches Xvnc, Fluxbox, XTerm, websockify
    │
    ├── wrappers/
    │   └── google-chrome.sh   # Nix replaceVars template (proxy-aware)
    │
    ├── config/
    │   ├── Xresources                    # XTerm color scheme + font + keybinds
    │   ├── proxychains.conf.template     # proxychains-ng SOCKS5 template
    │   └── fluxbox/
    │       ├── init                      # Fluxbox workspace settings
    │       ├── startup                   # Fluxbox autostart (xsetroot + exec)
    │       ├── menu.template             # Right-click menu with {{placeholders}}
    │       └── keys.template             # Keyboard shortcuts with {{placeholders}}
    │
    ├── v2ray-client.json.example         # VMess VPN config template
    └── v2ray-client-reality.json.example # VLESS Reality VPN config template
```

---

## Two-Phase Nix Architecture

The project uses Nix in **two distinct phases** with different purposes:

### Phase 1: Bootstrap (`idx-template.nix`)

Runs **once** when the workspace is created. Produces the `$out` directory.

| Aspect | Detail |
|--------|--------|
| **When** | Workspace creation only |
| **Channel** | `unstable` |
| **Packages** | `curl`, `git`, `busybox`, `nix`, `chromium`, `antigravity` |
| **Action** | Copies `out/` → `$out`, copies `flake.nix` + `camoufox/`, symlinks binaries into `$out/bin/` |

### Phase 2: Runtime (`out/.idx/dev.nix` + `flake.nix`)

Runs **every time** the workspace starts.

| File | Purpose |
|------|---------|
| `out/.idx/dev.nix` | Firebase Studio environment: installs TigerVNC, Fluxbox, noVNC, Xray, fonts, etc. Configures the web preview to run `start-with-vnc.sh` |
| `flake.nix` | Builds a `vnc-browser-env` package via `nix build`. Creates Chromium/Camoufox wrapper scripts with proxy detection and hardcoded flags using `replaceVars` |

---

## Component Details

### VNC Display Stack

```
Xvnc :99 (5900)  →  Fluxbox (window manager)  →  websockify (5999)  →  noVNC (browser)
```

- **Xvnc** — Headless X server with built-in VNC, 1920×1080@24bit, no auth
- **Fluxbox** — Lightweight WM with 4 workspaces (Main, Web, Term, Misc)
- **websockify** — Bridges VNC protocol to WebSocket for noVNC
- **noVNC** — Cloned at first boot from GitHub; serves the web VNC client

Port assignment is UID-based to avoid collisions in multi-user environments:
```
DISPLAY_NUM = UID % 100 + 10
VNC_PORT    = 5900 + DISPLAY_NUM
NOVNC_PORT  = 6000 + DISPLAY_NUM  (overridden by Firebase $PORT)
```

### Browser Wrappers

Three browser types, each with direct and VPN-proxy variants:

| Browser | Direct Launcher | VPN Launcher | Notes |
|---------|----------------|--------------|-------|
| **Chromium** | `~/.local/bin/browser` | `~/.local/bin/browser-proxy` | Hardcoded `--no-sandbox`, `--jitless`, Ozone/X11 flags |
| **Camoufox** | `~/.local/bin/camoufox-browser-{1,2}` | `~/.local/bin/camoufox-proxy` | Anti-detect Firefox fork; separate profiles allow parallel instances |
| **Antigravity** | `~/.local/bin/antigravity` | `~/.local/bin/antigravity-proxy` | Unfree package; proxy via proxychains4 |

The `flake.nix` creates an additional set of wrappers (`google-chrome`, `chromium`, `xdg-open`) via `replaceVars` that auto-detect `$PROXY_SOCKS5` at launch time.

### VPN (Xray) Integration

```
Xray (xray run -config ...)
  ├── SOCKS5 inbound → 127.0.0.1:10808
  └── HTTP   inbound → 127.0.0.1:10809
        │
        ├──→ Browser --proxy-server=socks5://...
        ├──→ proxychains4 (for Antigravity)
        └──→ Shell: source ~/.xray-proxy.env
```

**Routing rules** bypass the proxy for:
- Localhost / private IPs
- VNC ports (5900, 5999)
- The workstation's own `cloudworkstations.dev` domain

Supports two Xray protocols:
- **VMess** (WebSocket) — `v2ray-client.json`
- **VLESS Reality** (TCP/TLS) — `v2ray-client-reality.json`

### Template Rendering System

`lib.sh` provides `render_template()` which replaces `{{KEY}}` placeholders in config files:

```
config/fluxbox/menu.template  →  ~/.fluxbox/menu
config/fluxbox/keys.template  →  ~/.fluxbox/keys
config/proxychains.conf.template  →  ~/.proxychains.conf
```

This allows menu entries and keyboard shortcuts to reference dynamically-resolved binary paths.

---

## Startup Sequence

```mermaid
graph TD
    A["just start → start-with-vnc.sh"] --> B["source config.env + lib.sh"]
    B --> C["setup_fonts — discover Nix store fonts"]
    B --> D["setup_dbus — start session bus"]
    B --> E["setup_gpu_env — force software rendering"]
    B --> F{"VPN config exists?"}
    F -- Yes --> G["start-vpn.sh → Xray"]
    G --> G1["Wait for SOCKS/HTTP ports"]
    G --> G2["export_proxy_vars → ~/.xray-proxy.env"]
    F -- No --> H["Direct connection"]
    G1 --> I["setup_launchers — generate ~/.local/bin/ scripts"]
    H --> I
    I --> J["setup_fluxbox — render menu/keys/proxychains"]
    J --> K["setup_xdg — .desktop files + mimeapps.list"]
    K --> L["start_vnc_server"]
    L --> L1["Xvnc :99 → port 5900"]
    L --> L2["xrdb merge Xresources"]
    L --> L3["Fluxbox window manager"]
    L --> L4["Auto XTerm (black bg)"]
    L --> L5["websockify → noVNC on $PORT"]
    L5 --> M["wait $WEBSOCKIFY_PID — keep alive"]
```

---

## Service Management

| Command | Script | Action |
|---------|--------|--------|
| `just start` | `start-with-vnc.sh` | Full boot: VPN → Desktop → VNC |
| `just stop` | `stop-vnc.sh` | Graceful shutdown of all PIDs + cleanup |
| `just status` | `status-vnc.sh` | Process check, VPN test, URL display |
| `just vpn` | `start-vpn.sh` | Start VPN only |
| `just vpn-stop` | `stop-vpn.sh` | Stop Xray + clear proxy env |

PID tracking: all process IDs are written to `~/.antigravity-vnc.pid` for reliable cleanup.

---

## Keyboard Shortcuts (Fluxbox)

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+T` | Open XTerm |
| `Ctrl+Alt+B` | Open Chromium |
| `Ctrl+Alt+1` | Open Camoufox (Profile 1) |
| `Ctrl+Alt+2` | Open Camoufox (Profile 2) |
| `Alt+Tab` | Next window |
| `Alt+F4` | Close window |
| `Alt+F10` | Maximize |
| `Super+Left/Right` | Snap window to half screen |

---

## Security & Environment Notes

- **`host.virtualization = true`** in `idx-template.json` requests a VM-backed workspace (needed for Xvnc)
- **GPU disabled** — all rendering is software-based (Mesa llvmpipe / swrast)
- **Chromium flags** — `--no-sandbox`, `--jitless`, `--disable-gpu` for headless VM compatibility
- **Camoufox** — ELF interpreters are patched via `patchelf`; anti-detection policies are relaxed to restore search engines
- **`allowUnfree = true`** — required for the `antigravity` package
