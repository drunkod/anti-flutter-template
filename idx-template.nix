# Bootstrap script for Slint Android template creation.
{ pkgs, ... }: {
  channel = "stable-25.05";

  packages = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnutar
    pkgs.xz
    pkgs.git
  ];

  bootstrap = ''
    mkdir -p "$out"/src
    mkdir -p "$out"/.idx/modules/gstreamer-android
    mkdir -p "$out"/.idx/modules/slint-android
    mkdir -p "$out"/.idx/overlays
    mkdir -p "$out"/.idx/scripts

    install -m 644 ${./Cargo.toml} "$out"/Cargo.toml
    install -m 644 ${./flake.nix} "$out"/flake.nix
    install -m 644 ${./dev.nix} "$out"/dev.nix
    install -m 644 ${./README.md} "$out"/README.md
    install -m 644 ${./bashrc} "$out"/bashrc
    install -m 755 ${./cargo_store.sh} "$out"/cargo_store.sh

    install -m 644 ${./src/lib.rs} "$out"/src/lib.rs

    install -m 644 ${./.idx/dev.nix} "$out"/.idx/dev.nix
    install -m 644 ${./.idx/modules/environment.nix} "$out"/.idx/modules/environment.nix
    install -m 644 ${./.idx/modules/packages.nix} "$out"/.idx/modules/packages.nix
    install -m 644 ${./.idx/modules/previews.nix} "$out"/.idx/modules/previews.nix
    install -m 644 ${./.idx/modules/workspace.nix} "$out"/.idx/modules/workspace.nix
    install -m 644 ${./.idx/modules/gstreamer-android/default.nix} "$out"/.idx/modules/gstreamer-android/default.nix
    install -m 644 ${./.idx/modules/slint-android/default.nix} "$out"/.idx/modules/slint-android/default.nix
    install -m 644 ${./.idx/modules/slint-android/emulator.nix} "$out"/.idx/modules/slint-android/emulator.nix

    install -m 644 ${./.idx/overlays/android.nix} "$out"/.idx/overlays/android.nix
    install -m 644 ${./.idx/overlays/default.nix} "$out"/.idx/overlays/default.nix
    install -m 644 ${./.idx/overlays/fenix.nix} "$out"/.idx/overlays/fenix.nix
    install -m 644 ${./.idx/overlays/rust.nix} "$out"/.idx/overlays/rust.nix

    install -m 644 ${./.idx/scripts/enable-slint.nix} "$out"/.idx/scripts/enable-slint.nix
    install -m 755 ${./.idx/scripts/load-slint.sh} "$out"/.idx/scripts/load-slint.sh

    chmod -R u+w "$out"
  '';
}
