# Slint Android Template

A Project IDX template for building Android apps with Rust + Slint using Nix.

## Included

- Rust Android app skeleton (`src/lib.rs`, `Cargo.toml`)
- IDX environment modules under `.idx/`
- Android and Rust overlays (`.idx/overlays/*`)
- Helper scripts (`.idx/scripts/*`, `cargo_store.sh`)
- `flake.nix` with `default` and `slint` dev shells

## Quick Start

```bash
nix develop .#slint
slint-android-info
slint-android-build aarch64-linux-android
```

## Template Files

`idx-template.nix` copies the project skeleton into generated output and includes all `.idx` modules.
