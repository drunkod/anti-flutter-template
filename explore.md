# Codebase Overview

An **Antigravity VNC workspace** with a built-in **Project IDX Flutter template** for bootstrapping Flutter projects. **Dart-only** — no Firebase, JDK, or Android emulator.

## Architecture

Two systems coexist in this repo:

### 1. Antigravity Infrastructure (VNC + VPN)

```
.idx/dev.nix          ← Workspace runtime (tigervnc, fluxbox, antigravity)
config.env            ← Shared config (ports, paths, patterns)
lib.sh                ← Shared bash utilities (logging, process mgmt, proxy)
flake.nix             ← Nix build (antigravity + chromium wrapper)
justfile              ← Task runner (just start/stop/status)

start-with-vnc.sh     ← Main orchestrator
├── scripts/setup-fonts.sh
├── scripts/setup-dbus.sh
├── scripts/setup-gpu-env.sh
├── scripts/setup-fluxbox.sh
├── scripts/start-vnc-server.sh
├── scripts/build-app.sh
└── scripts/launch-app.sh

start-vpn.sh / stop-vpn.sh  ← Xray VPN proxy management
stop-vnc.sh / status-vnc.sh ← Service lifecycle

config/               ← Xresources, fluxbox templates, proxychains
wrappers/             ← google-chrome.sh (proxy-aware browser wrapper)
v2ray-client*.example ← VPN config templates
```

### 2. Flutter Template (IDX)

```
┌─────────────────────┐
│  idx-template.json  │  ← Template UI params (shown to users)
└────────┬────────────┘
         │ feeds params into
         ▼
┌─────────────────────┐
│  idx-template.nix   │  ← Bootstrap (runs `flutter create` with params)
└────────┬────────────┘
         │ copies
         ▼
┌─────────────────────┐
│      dev.nix        │  ← Dart-only runtime (web preview, no JDK/Firebase)
└─────────────────────┘

scripts/update.dart + Makefile  ← Code-gen: regenerates idx-template.json
```

## File Roles

### `.idx/dev.nix` — Antigravity Workspace Config
This is the **workspace itself** (NOT the Flutter template). Installs:
- `tigervnc`, `fluxbox`, `websockify`, `novnc`, `antigravity`

### `dev.nix` (root) — Flutter Template Runtime
Copied into **generated Flutter projects**. Dart-only:
- **Packages**: `unzip` only (no firebase-tools, no JDK)
- **Extensions**: Flutter & Dart VS Code extensions
- **Previews**: Web only (no Android emulator)
- **onCreate**: `flutter pub get`

### `idx-template.json` — Template Definition
Exposes **6 parameters** in the IDX "new project" UI:

| Param | Type | Purpose |
|-------|------|---------|
| `template` | enum | `app`, `module`, `package`, `plugin`, `plugin_ffi`, `skeleton` |
| `sample` | enum | ~500+ Flutter widget samples (or "None") |
| `blank` | boolean | Skip boilerplate comments (`-e` flag) |
| `platforms` | text | Comma-separated: `web,linux,macos,windows` |
| `org` | text | Organization (e.g. `com.example`) |
| `project-name` | text | Project name |

### `idx-template.nix` — Bootstrap Script
Runs when a new workspace is created:
```nix
flutter create "$out" \
  --template="${template}" \
  --platforms="${platforms}" \
  ${if sample == "none" then "" else "--sample=${sample}"} \
  ${if blank then "-e" else ""}
```
Then copies root `dev.nix` into `$out/.idx/dev.nix`.

### `scripts/update.dart` + `Makefile` — Code-Gen
Regenerates `idx-template.json` from Flutter's sample registry:
```bash
make update
```

## Notable Details

1. **Two dev.nix files**: `.idx/dev.nix` is Antigravity workspace; root `dev.nix` is the Flutter template.
2. **Dart-only template**: No firebase-tools, JDK, or emulator. Web preview only.
3. **`virtualization: true`** (boolean, not string) in both `idx-template.json` and `update.dart`.
4. **Both Nix files target `stable-25.05`** channel for the Flutter template.
5. **`org` and `project-name`** params are exposed in the template UI.
6. **Sample list** (~500+ entries) is auto-generated from Flutter's sample registry.
