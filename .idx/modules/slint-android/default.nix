# .idx/modules/slint-android/default.nix
{ pkgs, lib, system }:

let
  platformVersion = pkgs.androidPlatformVersion;
  androidComposition = pkgs.androidComposition;
  androidSdk = pkgs.androidSdk;
  rustToolchain = pkgs.rustToolchain;

  currentPath = builtins.getEnv "PWD";

  runAndroidScript = pkgs.writeShellScriptBin "slint-android-run" ''
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET="''${1:-aarch64-linux-android}"

    echo "Building and running Slint Android app..."
    echo "Target: $TARGET"
    echo ""
    echo "Make sure your device is connected via ADB"
    echo ""

    cargo apk run --target "$TARGET" --lib
  '';

  buildApkScript = pkgs.writeShellScriptBin "slint-android-build" ''
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET="''${1:-aarch64-linux-android}"
    MODE="''${2:-debug}"

    echo "Building Slint Android APK..."
    echo "Target: $TARGET"
    echo "Mode: $MODE"
    echo ""

    if [ "$MODE" = "release" ]; then
      cargo apk build --target "$TARGET" --lib --release
    else
      cargo apk build --target "$TARGET" --lib
    fi

    echo ""
    echo "APK built successfully"
    find target -name "*.apk" -type f | head -5
  '';

  installApkScript = pkgs.writeShellScriptBin "slint-android-install" ''
    #!/usr/bin/env bash
    set -euo pipefail

    APK_PATH="''${1:-}"

    if [ -z "$APK_PATH" ]; then
      echo "Looking for APK files..."
      APK_PATH=$(find target -name "*.apk" -type f | head -1)
    fi

    if [ -z "$APK_PATH" ] || [ ! -f "$APK_PATH" ]; then
      echo "No APK file found. Build one first with 'slint-android-build'"
      exit 1
    fi

    echo "Installing APK: $APK_PATH"
    adb install -r "$APK_PATH"
  '';

  infoScript = pkgs.writeShellScriptBin "slint-android-info" ''
    #!/usr/bin/env bash
    echo ""
    echo "Slint Android Development Environment"
    echo ""
    echo "Configuration:"
    echo "  Platform: Android ${platformVersion}"
    echo "  SDK: $ANDROID_HOME"
    echo "  NDK: $ANDROID_NDK_ROOT"
    echo "  Java: $JAVA_HOME"
    echo "  Rust: $(rustc --version 2>/dev/null || echo 'N/A')"
    echo ""
    echo "Targets:"
    echo "  aarch64-linux-android (ARM64 devices)"
    echo "  armv7-linux-androideabi (ARM devices)"
    echo ""
    echo "Commands:"
    echo "  slint-android-build [target] [mode]"
    echo "  slint-android-run [target]"
    echo "  slint-android-install [apk]"
    echo "  slint-android-info"
    echo ""
    echo "Examples:"
    echo "  slint-android-build"
    echo "  slint-android-build aarch64-linux-android release"
    echo "  slint-android-run aarch64-linux-android"
    echo "  slint-android-install target/debug/apk/*.apk"
    echo ""
    echo "Device connection:"
    echo "  adb devices"
    echo "  adb logcat"
    echo ""
  '';
in {
  packages = [
    rustToolchain
    pkgs.cargo-apk
    pkgs.jdk17
    androidSdk
    pkgs.android-tools
    buildApkScript
    runAndroidScript
    installApkScript
    infoScript
  ];

  env = {
    ANDROID_HOME = "${androidComposition.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
    ANDROID_NDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk/ndk-bundle";
    JAVA_HOME = "${pkgs.jdk17}";

    CARGO_HOME = "${currentPath}/.cargo-home";

    LD_LIBRARY_PATH = lib.makeLibraryPath (with pkgs; [
      wayland
      libxkbcommon
      fontconfig
    ]);
  };

  inherit androidComposition;

  shellHook = ''
    if [ -z "$_SLINT_ANDROID_INIT" ]; then
      export _SLINT_ANDROID_INIT=1
      echo "Slint Android environment ready"
      echo "Run 'slint-android-info' for help"
      echo ""
      echo "Emulator removed to save space"
      echo "Connect a physical device via USB for testing"
    fi
  '';
}
