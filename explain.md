# Camoufox Integration Notes

This document explains how Camoufox was integrated into this workspace with two isolated browser launchers and Fluxbox menu entries.

## Source Baseline

The integration is based on the Camoufox Nix packaging approach from:

- `https://github.com/pabx06/camoufox-nix/blob/main/flake.nix`

Key packaging points reused:

- Download release zip from Camoufox GitHub releases
- Use `autoPatchelfHook` + GTK/Glib/X11 runtime dependencies
- Wrap with `wrapGAppsHook3` for `XDG_DATA_DIRS` and runtime schema loading
- Expose `camoufox` binary from `$out/bin`

## What Was Added

### 1. New folder: `camoufox/`

- `camoufox/browser-1.sh`
- `camoufox/browser-2.sh`
- `camoufox/README.md`

Both launchers use:

- `--no-remote`
- `--new-instance`
- profile isolation (`~/.camoufox/profile-1` and `~/.camoufox/profile-2`)
- container-safe defaults (`MOZ_DISABLE_*_SANDBOX=1`, software rendering)

This allows running two independent Camoufox sessions in parallel.

### 2. `flake.nix` integration

Added:

- `camoufoxPkg` derivation (version `135.0.1-beta.24`)
- Wrapper generation with `pkgs.replaceVars` for:
  - `camoufox-browser-1`
  - `camoufox-browser-2`
- Inclusion of Camoufox in package output:
  - `paths = [ pkgs.antigravity camoufoxPkg ];`

Installed binaries now include:

- `result/bin/camoufox`
- `result/bin/camoufox-browser-1`
- `result/bin/camoufox-browser-2`

### 3. Environment + startup script wiring

Added env vars in `config.env`:

- `CAMOUFOX_BROWSER1_CMD`
- `CAMOUFOX_BROWSER2_CMD`

Updated `scripts/build-app.sh` to symlink built launchers into `~/.local/bin` targets so Fluxbox menu entries always point to stable paths.

### 4. Fluxbox menu integration

Updated `scripts/setup-fluxbox.sh`:

- Added launcher fallback resolution for Camoufox commands
- Added Fluxmenu entries for:
  - Camoufox #1
  - Camoufox #1 (google.com)
  - Camoufox #2
  - Camoufox #2 (check IP)
- Added hotkeys:
  - `Ctrl+Alt+1` -> Camoufox #1
  - `Ctrl+Alt+2` -> Camoufox #2

Reference templates were also updated:

- `config/fluxbox/menu.template`
- `config/fluxbox/keys.template`

### 5. Template propagation

Updated `idx-template.nix` so generated Flutter projects also include:

- `camoufox/browser-1.sh`
- `camoufox/browser-2.sh`
- `camoufox/README.md`

## Usage

1. Start workspace:

```bash
just start
```

2. Open Camoufox from Fluxbox menu:

- Right-click desktop -> `Web Browser` -> `Camoufox #1` or `Camoufox #2`

3. Or use shortcuts:

- `Ctrl+Alt+1`
- `Ctrl+Alt+2`
