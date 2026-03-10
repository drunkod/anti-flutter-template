# How This Template Works — Step by Step

A complete walkthrough of what happens from the moment a user clicks "Create workspace" to a running VNC desktop in their browser.

---

## Step 0: User Discovers the Template

The template is shared via URL:

```
https://studio.firebase.google.com/new?template=https://github.com/YOUR_USER/anti-flutter-template
```

Firebase Studio clones the repo and reads `idx-template.json`.

---

## Step 1: Firebase Studio Reads `idx-template.json`

```json
{
  "name": "Flutter",
  "description": "Flutter create template",
  "categories": ["Mobile"],
  "icon": "https://www.gstatic.com/.../flutter/v6/192px.svg",
  "host": { "virtualization": true },
  "params": [ ... ]
}
```

**What the user sees:**
- Template named **"Flutter"** with the Flutter logo
- Category: **Mobile**
- A form with 4 parameters:

| Parameter | Type | UI Element | Default |
|-----------|------|-----------|---------|
| `platforms` | `text` | Text field | `web` |
| `camoufox` | `boolean` | Checkbox ("Enable Camoufox") | `false` |
| `antigravity` | `boolean` | Checkbox ("Enable Antigravity") | `false` |
| `warp` | `boolean` | Checkbox ("Enable WARP VPN") | `false` |

**Key detail:** `"host": { "virtualization": true }` requests a **VM-backed workspace** instead of a container. This gives the kernel access needed to run an X server (Xvnc).

The user fills in the form and clicks **"Create"**.

---

## Step 2: Firebase Studio Executes `idx-template.nix`

Firebase passes the user's parameter values into the Nix function:

```nix
{ pkgs, sample ? "none", template ? "app", blank ? false, platforms ? "web",
  camoufox ? false, antigravity ? false, warp ? false, ... }:
```

### 2a. Prepare Dependencies (Conditional)

```nix
# Only imported when antigravity=true (avoids unfree overlay otherwise)
pkgsUnfree = if antigravity then import pkgs.path {
  inherit (pkgs) system;
  config.allowUnfree = true;
} else null;

# Only built when camoufox=true
camoufoxPkg = if camoufox then import ./camoufox/package.nix { inherit pkgs; } else null;
```

The Nix sandbox downloads and builds only what's needed:
- **Chromium** (from nixpkgs) — always
- **Camoufox** (fetched from GitHub releases, patched with `patchelf`, wrapped with `makeWrapper`) — only if `camoufox=true`
- **Antigravity** (unfree package) — only if `antigravity=true`
- **wgcf + wireproxy** (Cloudflare WARP tools) — only if `warp=true`

### 2b. Bootstrap Script Runs

The `flutter create` command is **commented out** — it never runs:

```bash
# flutter create "$out" \
#  --template="${template}" \
#  --platforms="${platforms}" ...
```

Instead, 8 operations build the workspace:

**Operation 1 — Copy runtime files:**
```bash
cp -r ${./out}/. "$out"/
chmod -R u+w "$out"
```
Everything in `out/` (scripts, configs, justfile, VPN examples) becomes the workspace root.

**Operation 2 — Copy flake.nix:**
```bash
install -m 644 ${./flake.nix} "$out"/flake.nix
```
The runtime Nix flake that builds browser wrappers.

**Operation 3 — Copy camoufox sub-flake** (only when `camoufox=true`):
```bash
mkdir -p "$out"/camoufox
install -m 644 ${./camoufox/flake.nix} "$out"/camoufox/flake.nix
install -m 755 ${./camoufox/browser-1.sh} "$out"/camoufox/browser-1.sh
install -m 755 ${./camoufox/browser-2.sh} "$out"/camoufox/browser-2.sh
```

**Operation 4 — Symlink binaries** (conditional):
```bash
mkdir -p "$out"/bin
ln -sf ${pkgs.chromium}/bin/chromium "$out"/bin/chromium          # always
# if camoufox=true:
ln -sf ${camoufoxPkg}/bin/camoufox "$out"/bin/camoufox
ln -sf ${camoufoxPkg}/bin/camoufox-bin "$out"/bin/camoufox-bin
# if antigravity=true:
ln -sf ${pkgsUnfree.antigravity}/bin/antigravity "$out"/bin/antigravity
# if warp=true:
ln -sf ${pkgs.wgcf}/bin/wgcf "$out"/bin/wgcf
ln -sf ${pkgs.wireproxy}/bin/wireproxy "$out"/bin/wireproxy
```
These Nix store symlinks make the binaries available at `./bin/` in the workspace, without needing them in `dev.nix` packages.

**Operation 5 — Generate `dev.nix` from Jinja2 template:**
```bash
warp=${if warp then "true" else "false"} j2 devNix.j2 -o "$out"/.idx/dev.nix
nixfmt "$out"/.idx/dev.nix
```
`devNix.j2` uses Jinja2 conditionals (`{% if warp == "true" %}`) to include WARP-specific packages (`pkgs.wgcf`, `pkgs.wireproxy`) and an `onStart` hook that auto-starts wireproxy. This follows the same pattern as the official Astro template.

**Operation 6 — WARP setup** (only when `warp=true`):
```bash
mkdir -p "$out"/warp
wgcf register --accept-tos     # Register free WARP account
wgcf generate                  # Generate WireGuard profile
cp wgcf-profile.conf wireproxy.conf
# Append [Socks5] section → SOCKS5 on 127.0.0.1:40000
```
This runs during bootstrap so the WARP account is ready immediately.

### 2c. Result

`$out` now contains a complete workspace directory. Firebase Studio creates the workspace from it.

> **Note:** `dev.nix` is no longer a static file in the repo — it is generated dynamically from `devNix.j2` at bootstrap time.

---

## Step 3: Workspace Environment Activates (generated `dev.nix`)

Firebase Studio reads `.idx/dev.nix` (generated from `devNix.j2`) to configure the running environment:

### 3a. Runtime Packages Installed

```nix
packages = [
  pkgs.tigervnc          # Xvnc server
  pkgs.fluxbox           # Window manager
  pkgs.python313Packages.websockify  # VNC→WebSocket bridge
  pkgs.novnc             # Browser-based VNC client
  pkgs.xterm             # Terminal emulator
  pkgs.xray              # VPN proxy engine
  pkgs.proxychains-ng    # Force any app through SOCKS proxy
  pkgs.dbus              # Desktop bus
  pkgs.xdotool           # X automation
  pkgs.xorg.xrdb         # X resource database
  pkgs.fontconfig pkgs.dejavu_fonts pkgs.liberation_ttf pkgs.noto-fonts
  pkgs.wget pkgs.unzip pkgs.psmisc
  # When warp=true, also includes:
  # pkgs.wgcf pkgs.wireproxy
];
```

These are **workspace-runtime** packages — different from the bootstrap-only packages in `idx-template.nix`.

### 3b. Hooks

```nix
onCreate = {
  default.openFiles = [ "README.md" ];
};
# When warp=true, also includes:
# onStart = {
#   startWarp = "./scripts/start-warp.sh start";
# };
```

`onCreate` opens the README when the workspace is first created. When WARP is enabled, `onStart` auto-starts wireproxy on every workspace boot.

### 3c. Web Preview Configured

```nix
previews = {
  enable = true;
  previews = {
    web = {
      command = [ "bash" "-c" "NOVNC_PORT=$PORT ./start-with-vnc.sh" ];
      manager = "web";
      env = { PORT = "$PORT"; };
    };
  };
};
```

Firebase Studio assigns a dynamic `$PORT` and runs `start-with-vnc.sh` with `NOVNC_PORT` set to that port. The preview panel opens the noVNC web page.

---

## Step 4: `start-with-vnc.sh` Orchestrates the Desktop

This is the main entry point. Here's exactly what happens, in order:

### 4a. Load Configuration

```bash
source "$SCRIPT_DIR/config.env"    # Ports, paths, flags
source "$SCRIPT_DIR/lib.sh"        # Helper functions
```

`config.env` computes all values:
- `DISPLAY_NUM` = UID-based (avoids collisions)
- `VNC_PORT` = 5900 + display num
- `NOVNC_PORT` = from Firebase `$PORT` (overrides default)
- `SOCKS_PORT` = 10808, `HTTP_PORT` = 10809
- `CHROMIUM_FLAGS` = 15 flags for headless VM compatibility
- `NOVNC_URL` = auto-detected from workstation hostname

### 4b. Set Environment

```bash
export DISPLAY=":$DISPLAY_NUM"
export NIXPKGS_ALLOW_UNFREE=1
export PATH="$SCRIPT_DIR/bin:$HOME/.local/bin:$PATH"
```

This puts the symlinked binaries (`./bin/chromium`, `./bin/camoufox`) on PATH.

### 4c. Clean Previous Run

```bash
"$SCRIPT_DIR/stop-vnc.sh" >/dev/null 2>&1 || true
rm -f "$PID_FILE"
```

### 4d. `setup_fonts` → Font Discovery

Scans the Nix store for font directories and writes `~/.config/fontconfig/fonts.conf`:

```xml
<fontconfig>
  <dir>/nix/store/...-dejavu-fonts/share/fonts</dir>
  <dir>/nix/store/...-noto-fonts/share/fonts</dir>
  ...
</fontconfig>
```

Verifies fonts are discoverable via `fc-list`.

### 4e. `setup_dbus` → Session Bus

1. Creates `$XDG_RUNTIME_DIR` with mode 700
2. Generates a machine UUID
3. Starts `dbus-daemon` with the session config
4. Exports `DBUS_SESSION_BUS_ADDRESS`

Required by GTK apps (Chromium, Camoufox) for desktop integration.

### 4f. `setup_gpu_env` → Software Rendering

```bash
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GALLIUM_DRIVER=llvmpipe
export VK_ICD_FILENAMES=""           # Disable Vulkan
export ALSA_CONFIG_PATH="/dev/null"  # Suppress audio warnings
```

No GPU is available in the VM, so all graphics use software rasterization.

### 4g. VPN (Conditional)

```bash
if [ -f "$SCRIPT_DIR/$VPN_CONFIG_FILE" ]; then
    "$SCRIPT_DIR/start-vpn.sh" "$VPN_CONFIG"
fi
```

**If `v2ray-client.json` or `v2ray-client-reality.json` exists:**

1. Replaces `YOUR_WORKSTATION_DOMAIN` placeholder with auto-detected domain
2. Validates no other placeholders remain
3. Launches `xray run -config ...` in background
4. Waits for SOCKS5 (10808) and HTTP (10809) ports
5. Tests connectivity: fetches `ifconfig.me` through proxy vs direct
6. Writes proxy env vars to `~/.xray-proxy.env`
7. Sources the env file (so subsequent commands use the proxy)

**If no config exists:** skips VPN, continues with direct connection.

### 4g-bis. WARP VPN (Conditional)

```bash
if [ -f "$WARP_DIR/wireproxy.conf" ]; then
    "$SCRIPT_DIR/scripts/start-warp.sh" start
fi
```

**If `warp/wireproxy.conf` exists** (created during bootstrap when `warp=true`):

1. Runs `setup_warp()` — verifies `wgcf`/`wireproxy` binaries, ensures account + profile exist
2. Runs `start_warp()` — launches `wireproxy` in background
3. Waits for SOCKS5 port 40000
4. Tests connectivity through the WARP proxy
5. Writes `~/.warp-proxy.env` with `WARP_SOCKS_PROXY` and `WARP_SOCKS_PORT`

**If no wireproxy.conf exists:** skips WARP, continues normally. Both Xray and WARP can run simultaneously (on different ports).

### 4h. `setup_launchers` → Generate Browser Scripts

Creates executable scripts in `~/.local/bin/`:

**Chromium direct** (`~/.local/bin/browser`):
```bash
#!/usr/bin/env bash
flags=( --no-sandbox --disable-gpu ... )  # 15 flags from config.env
exec /nix/store/.../chromium "${flags[@]}" "$@"
```

**Chromium via Xray VPN** (`~/.local/bin/browser-proxy`):
```bash
exec chromium "${flags[@]}" --proxy-server="socks5://127.0.0.1:10808" "$@"
```

**Chromium via WARP** (`~/.local/bin/browser-warp`):
```bash
exec chromium "${flags[@]}" --proxy-server="socks5://127.0.0.1:40000" "$@"
```

**Camoufox #1** (`~/.local/bin/camoufox-browser-1`):
```bash
profile_dir="$HOME/.camoufox/profile-1"
mkdir -p "$profile_dir"
exec camoufox -no-remote -new-instance -profile "$profile_dir" "$@"
```

**Camoufox #2** — same but `profile-2` (allows parallel instances).

**Camoufox Xray VPN** — adds `--proxy-server=socks5://127.0.0.1:10808`.

**Camoufox WARP** (`~/.local/bin/camoufox-warp`) — uses `profile-warp`, adds `--proxy-server=socks5://127.0.0.1:40000`.

**Antigravity** — direct symlink + Xray proxy version via `proxychains4`.

**Antigravity WARP** (`~/.local/bin/antigravity-warp`) — routes through `proxychains4 -f ~/.proxychains-warp.conf`.

WARP launchers are only created when the corresponding binary (chromium, camoufox, antigravity) is found.

### 4i. `setup_fluxbox` → Render Desktop Config

Uses `render_template()` to replace `{{placeholders}}` with actual paths:

```
config/fluxbox/menu.template  →  ~/.fluxbox/menu
   {{BROWSER_CMD}}           →  /home/user/.local/bin/browser
   {{BROWSER_WARP_CMD}}      →  /home/user/.local/bin/browser-warp
   {{CAMOUFOX_BROWSER1_CMD}} →  /home/user/.local/bin/camoufox-browser-1
   {{CAMOUFOX_WARP_CMD}}     →  /home/user/.local/bin/camoufox-warp
   {{ANTIGRAVITY_WARP_CMD}}  →  /home/user/.local/bin/antigravity-warp
   {{SOCKS_PORT}}            →  10808
   {{WARP_SOCKS_PORT}}       →  40000
   ...

config/fluxbox/keys.template →  ~/.fluxbox/keys
   {{BROWSER_CMD}}           →  /home/user/.local/bin/browser
   ...

config/proxychains.conf.template → ~/.proxychains.conf
   {{SOCKS_PORT}}            →  10808

config/proxychains-warp.conf.template → ~/.proxychains-warp.conf
   {{WARP_SOCKS_PORT}}       →  40000
```

Also copies `init` (Fluxbox settings), `startup` (autostart), and `Xresources` (XTerm theme).

### 4j. `setup_xdg` → Default Browser

1. Creates `.desktop` files for Chromium and Camoufox
2. Writes `~/.config/mimeapps.list` to set Chromium as the default for URLs
3. Sets `$BROWSER` env var
4. Creates `xdg-open` shim if `xdg-utils` is missing

### 4k. `start_vnc_server` → Launch Display Stack

**1. Clone noVNC** (first run only):
```bash
git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
```

**2. Start Xvnc:**
```bash
Xvnc :99 -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport 5900
```

**3. Load X resources:**
```bash
xrdb -merge ~/.Xresources    # Dark theme, DejaVu font, copy/paste shortcuts
```

**4. Start Fluxbox:**
```bash
DISPLAY=:99 fluxbox &
```
Reads `~/.fluxbox/init`, `~/.fluxbox/startup` (sets background to `#2d2d2d`).

**5. Auto-launch XTerm:**
```bash
DISPLAY=:99 xterm -bg black -fg white -geometry 100x30+50+50 &
```

**6. Start websockify:**
```bash
websockify --web=~/noVNC $NOVNC_PORT localhost:5900 &
```
Bridges VNC to WebSocket and serves the noVNC HTML client.

### 4l. Save PIDs & Wait

```bash
cat > ~/.antigravity-vnc.pid <<EOF
VNC_PID=...
FLUXBOX_PID=...
WEBSOCKIFY_PID=...
DBUS_PID=...
XRAY_PID=...
WIREPROXY_PID=...
EOF

wait $WEBSOCKIFY_PID
```

The PID file now includes `WIREPROXY_PID` (empty if WARP not active). The `wait` keeps the preview process alive. If websockify dies, the preview stops.

---

## Step 5: User Sees the Desktop

The Firebase Studio preview panel loads:

```
https://{PORT}-{workstation-host}.cloudworkstations.dev/vnc.html
```

This is the noVNC web client connecting to Xvnc through websockify. The user sees:

- A **Fluxbox desktop** with dark background
- An **XTerm** terminal window already open
- **Right-click menu** with:
  - Terminal variants (dark, large, login shell)
  - Chromium (direct + Xray VPN)
  - Camoufox #1 / #2 (direct + Xray VPN)
  - Antigravity (direct + Xray VPN)
  - **WARP Proxy** submenu:
    - Chromium / Camoufox / Antigravity via WARP
    - Start / Stop / Status WARP
    - WARP IP Check and log viewer
  - System tools (files, disk, processes, network)
  - VPN status/logs

---

## Step 6: Xray VPN Usage (Optional)

If the user wants Xray VPN:

1. Copy an example config:
   ```bash
   cp v2ray-client.json.example v2ray-client.json
   ```

2. Edit with real server details (replace `YOUR_SERVER_ADDRESS`, `YOUR-UUID-HERE`, etc.)

3. Restart:
   ```bash
   just stop && just start
   ```

4. `start-with-vnc.sh` detects the config file and runs `start-vpn.sh` automatically

5. All "VPN" menu entries now route through the Xray SOCKS5 proxy (:10808)

The VPN routing rules ensure **local traffic bypasses the proxy**:
- `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- VNC ports `5900`, `5999`
- `*.cloudworkstations.dev` (the workstation itself)

---

## Step 7: WARP VPN Usage (Optional)

If the template was created with `warp=true`:

- **Automatic**: WARP registers with Cloudflare and generates `wireproxy.conf` during bootstrap. On every start, `wireproxy` launches automatically — no user configuration needed.
- **Management via justfile**:
  ```bash
  just warp          # start / restart WARP
  just warp status   # check WARP connectivity
  just warp-stop     # stop wireproxy
  ```
- **Management via desktop menu**: Right-click → WARP Proxy → Start / Stop / Status
- **Browser routing**: All "WARP" menu entries route through `socks5://127.0.0.1:40000`
- **Coexists with Xray**: Xray (:10808/:10809) and WARP (:40000) run on separate ports — both can be active simultaneously

---

## Complete Data Flow

```
User's Browser
    │
    ▼
Firebase Studio Preview (iframe)
    │
    ▼ HTTPS WebSocket
noVNC client (~/noVNC)
    │
    ▼ WebSocket → VNC protocol
websockify (:$NOVNC_PORT)
    │
    ▼ TCP
Xvnc (:$DISPLAY_NUM, port $VNC_PORT)
    │
    ▼ X11 protocol
Fluxbox (window manager)
    │
    ├── XTerm (terminal)
    ├── Chromium ──→ direct internet
    │            ──→ Xray SOCKS5 (:10808) ──→ VPN server ──→ internet
    │            ──→ WARP SOCKS5 (:40000) ──→ Cloudflare WARP ──→ internet
    ├── Camoufox ──→ direct internet
    │            ──→ Xray SOCKS5 (:10808) ──→ VPN server ──→ internet
    │            ──→ WARP SOCKS5 (:40000) ──→ Cloudflare WARP ──→ internet
    ├── Antigravity ──→ proxychains4 ──→ Xray SOCKS5 ──→ VPN server ──→ internet
    │               ──→ proxychains4 ──→ WARP SOCKS5 ──→ Cloudflare WARP ──→ internet
    └── wireproxy (WARP) ──→ WireGuard tunnel ──→ Cloudflare edge ──→ internet
```

---

## Summary of Key Files and When They Run

| File | Runs | Purpose |
|------|------|---------|
| `idx-template.json` | Template selection UI | Displays params (platforms, camoufox, antigravity, warp) |
| `idx-template.nix` | Once at workspace creation | Copies files, conditional symlinks, renders `devNix.j2` |
| `devNix.j2` | Bootstrap (rendered to `.idx/dev.nix`) | Jinja2 template; conditionally includes WARP packages |
| `out/.idx/dev.nix` | Every workspace boot (generated) | Installs VNC/WM/browser packages; configures preview |
| `flake.nix` | On `nix build` (manual) | Builds wrapped browser commands with proxy detection |
| `config.env` | Every `start-with-vnc.sh` run | Single source of truth for all ports, paths, flags |
| `lib.sh` | Sourced by all scripts | Logging, process mgmt, proxy helpers, template renderer |
| `start-with-vnc.sh` | Preview start (via dev.nix) | Master orchestrator: VPN → WARP → launchers → Fluxbox → VNC |
| `scripts/setup-*.sh` | Sourced by orchestrator | Modular setup functions |
| `scripts/start-vnc-server.sh` | Sourced by orchestrator | Launches Xvnc + Fluxbox + XTerm + websockify |
| `start-vpn.sh` | If Xray VPN config exists | Starts Xray, tests connectivity, exports proxy vars |
| `scripts/start-warp.sh` | If `wireproxy.conf` exists | Manages wireproxy lifecycle (start/stop/status) |
| `config/proxychains-warp.conf.template` | Rendered by `setup_fluxbox` | proxychains4 config pointing to WARP SOCKS5 (:40000) |
| `stop-vnc.sh` | `just stop` or error handler | Kills all PIDs (incl. wireproxy), cleans up state |
| `camoufox/package.nix` | Nix build time | Fetches Camoufox binary, patches ELF, wraps with libs |
