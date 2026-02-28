# Shared Camoufox derivation builder.
# Called as: import ./package.nix { inherit pkgs; }
# Based on a working Firefox-style wrapper layout.
{ pkgs }:
let
  lib = pkgs.lib;
  version = "135.0.1-beta.24";

  systemMap = {
    "x86_64-linux" = {
      archSuffix = "lin.x86_64";
      sha256 = "sha256-k5t12L5q0RG8Zun0SAjGthYQXUcf+xVHvk9Mknr97QY=";
    };
    "aarch64-linux" = {
      archSuffix = "lin.arm64";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  info = systemMap.${system} or (throw "Unsupported system: ${system}");

  runtimeLibs = with pkgs; [
    # Core runtime
    stdenv.cc.cc.lib
    glib
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    libxkbcommon
    dbus
    alsa-lib
    fontconfig
    freetype
    libglvnd
    libdrm
    nss
    nspr

    # Browser integration / runtime features
    libnotify
    cups
    pciutils
    vulkan-loader
    libva
    libgbm
    pipewire
    libpulseaudio
    libcanberra-gtk3

    # X11 / desktop libs
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXinerama
  ];

  runtimeLibPath = lib.makeLibraryPath runtimeLibs;
  runtimeBinPath = lib.makeBinPath [ pkgs.xdg-utils ];
  xdgDataPath =
    "${pkgs.adwaita-icon-theme}/share:"
    + "${pkgs.gsettings-desktop-schemas}/share:"
    + "${pkgs.gtk3}/share";

  camoufox-unwrapped = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "camoufox-unwrapped";
    inherit version;

    src = pkgs.fetchzip {
      url = "https://github.com/daijro/camoufox/releases/download/v${version}/camoufox-${version}-${info.archSuffix}.zip";
      sha256 = info.sha256;
      stripRoot = false;
    };

    nativeBuildInputs = [
      pkgs.jq
      pkgs.patchelf
    ];

    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/camoufox"
      cp -a ./. "$out/lib/camoufox/"

      # Camoufox ships strict anti-network policies that can leave Firefox
      # with no valid default search engine in desktop/manual usage.
      if [ -f "$out/lib/camoufox/distribution/policies.json" ]; then
        tmp_policies="$(mktemp)"
        jq '
          if .policies then
            .policies |= (
              del(.SearchEngines)
              | if (.Extensions and .Extensions.Uninstall) then
                  .Extensions.Uninstall |= map(select(test("@search\\.mozilla\\.org$") | not))
                else
                  .
                end
            )
          else
            .
          end
        ' "$out/lib/camoufox/distribution/policies.json" > "$tmp_policies"
        mv "$tmp_policies" "$out/lib/camoufox/distribution/policies.json"
      fi

      if [ -f "$out/lib/camoufox/camoufox.cfg" ]; then
        sed -i 's|"browser.newtabpage.activity-stream.asrouter.providers.snippets", ""|"browser.newtabpage.activity-stream.asrouter.providers.snippets", "{}"|' "$out/lib/camoufox/camoufox.cfg"
      fi

      chmod +x "$out/lib/camoufox/camoufox"
      chmod +x "$out/lib/camoufox/camoufox-bin"

      # Camoufox releases may omit glxtest; Firefox expects it for GPU probing.
      if [ ! -e "$out/lib/camoufox/glxtest" ]; then
        ln -s ${pkgs.firefox-unwrapped}/lib/firefox/glxtest "$out/lib/camoufox/glxtest"
      fi

      # Patch only ELF interpreters; keep bundled libs unmodified.
      patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} "$out/lib/camoufox/camoufox"
      patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} "$out/lib/camoufox/camoufox-bin"

      runHook postInstall
    '';

    meta = with lib; {
      description = "A stealthy, minimalistic, custom build of Firefox for web scraping";
      homepage = "https://github.com/daijro/camoufox";
      license = licenses.mit;
      platforms = builtins.attrNames systemMap;
      mainProgram = "camoufox";
    };
  };

in
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "camoufox";
  inherit version;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  buildCommand = ''
    mkdir -p "$out/bin" "$out/lib"
    ln -s ${camoufox-unwrapped}/lib/camoufox "$out/lib/camoufox"

    makeWrapper ${camoufox-unwrapped}/lib/camoufox/camoufox "$out/bin/camoufox" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibPath}:${camoufox-unwrapped}/lib/camoufox" \
      --suffix PATH : "${runtimeBinPath}" \
      --suffix XDG_DATA_DIRS : "${xdgDataPath}" \
      --set MOZ_APP_LAUNCHER camoufox \
      --set MOZ_LEGACY_PROFILES 1 \
      --set MOZ_ALLOW_DOWNGRADE 1 \
      --set-default MOZ_ENABLE_WAYLAND 1 \
      --set-default LIBGL_ALWAYS_SOFTWARE 1 \
      --set-default MOZ_WEBRENDER 0 \
      --set-default MOZ_ACCELERATED 0 \
      --set-default GDK_DISABLE_GL 1

    makeWrapper ${camoufox-unwrapped}/lib/camoufox/camoufox-bin "$out/bin/camoufox-bin" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibPath}:${camoufox-unwrapped}/lib/camoufox" \
      --set-default LIBGL_ALWAYS_SOFTWARE 1 \
      --set-default MOZ_WEBRENDER 0 \
      --set-default MOZ_ACCELERATED 0 \
      --set-default GDK_DISABLE_GL 1
  '';

  passthru = {
    unwrapped = camoufox-unwrapped;
  };

  meta = camoufox-unwrapped.meta // {
    description = "Camoufox browser wrapped with Nix runtime environment";
    mainProgram = "camoufox";
  };
}
