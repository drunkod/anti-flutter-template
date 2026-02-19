# Anti-Flutter Template

An [Antigravity](https://github.com/nicolo-ribaudo/antigravity) workspace with a built-in **Project IDX Flutter template** for bootstrapping Flutter projects via `flutter create`.

**Dart-only** — no Firebase, JDK, or Android emulator required.

<a href="https://idx.google.com/new?template=https://github.com/project-idx/community-templates/tree/main/flutter-create">
  <img height="32" alt="Try in IDX" src="https://cdn.idx.dev/btn/try_dark_32.svg">
</a>

## Project Structure

```
├── .idx/
│   └── dev.nix                  # Antigravity workspace config (VNC, Fluxbox)
├── config/
│   ├── Xresources               # XTerm theme
│   ├── fluxbox/                  # Fluxbox menu/keys/init templates
│   └── proxychains.conf.template # VPN proxy config template
├── scripts/
│   ├── build-app.sh              # Nix build for Antigravity
│   ├── launch-app.sh             # Launch Antigravity in VNC
│   ├── setup-dbus.sh             # DBus session setup
│   ├── setup-fluxbox.sh          # Fluxbox config generation
│   ├── setup-fonts.sh            # Nix font configuration
│   ├── setup-gpu-env.sh          # Software rendering for headless
│   ├── start-vnc-server.sh       # VNC + noVNC + Fluxbox startup
│   └── update.dart               # Flutter template code-gen
├── wrappers/
│   └── google-chrome.sh          # Chrome wrapper w/ proxy support
├── camoufox/
│   ├── flake.nix                # External Camoufox package flake
│   ├── browser-1.sh              # Camoufox wrapper (profile-1)
│   ├── browser-2.sh              # Camoufox wrapper (profile-2)
│   └── README.md                 # Notes for dual Camoufox launchers
├── config.env                    # Shared environment variables
├── lib.sh                        # Shared bash utilities
├── flake.nix                     # Nix build definition
├── justfile                      # Task runner (just start/stop/status)
├── start-with-vnc.sh             # Main launcher (VNC + VPN + app)
├── start-vpn.sh                  # Xray VPN proxy launcher
├── stop-vnc.sh                   # Stop all services
├── stop-vpn.sh                   # Stop VPN only
├── status-vnc.sh                 # Service status check
├── dev.nix                       # Flutter template runtime (Dart-only)
├── idx-template.json             # Flutter template UI (~500 samples)
├── idx-template.nix              # Flutter bootstrap (flutter create)
├── Makefile                      # Regenerate Flutter samples
└── v2ray-client*.json.example    # VPN config examples
```

## Flutter Template

The Flutter template generates projects with only Dart (web preview):

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `template` | enum | `app` | `app`, `module`, `package`, `plugin`, `plugin_ffi`, `skeleton` |
| `sample` | enum | `none` | 500+ Flutter widget samples (auto-generated) |
| `blank` | boolean | `false` | Skip boilerplate comments (`-e` flag) |
| `platforms` | text | `web` | Comma-separated: `web,linux,macos,windows` |
| `org` | text | `com.example` | Organization identifier |
| `project-name` | text | `my_app` | Project name |

### Regenerate sample list

```bash
make update
```

## Antigravity Services

```bash
just start    # Launch VNC + VPN + Antigravity
just stop     # Stop all services
just status   # Check service status
just vpn      # Start VPN only
just vpn-stop # Stop VPN only
```

## Browser Launchers

- `Ctrl+Alt+B` launches Chromium
- `Ctrl+Alt+1` launches Camoufox profile 1
- `Ctrl+Alt+2` launches Camoufox profile 2
- Fluxbox menu includes Chromium + both Camoufox entries
