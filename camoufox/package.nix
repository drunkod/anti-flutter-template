# Shared Camoufox derivation builder.
# Called as: import ./package.nix { inherit pkgs; }
{ pkgs }:
let
  version = "135.0.1-beta.24";

  # Per-system archive mapping
  systemMap = {
    "x86_64-linux" = {
      archSuffix = "lin.x86_64";
      sha256 = "sha256-k5t12L5q0RG8Zun0SAjGthYQXUcf+xVHvk9Mknr97QY=";
    };
    "aarch64-linux" = {
      archSuffix = "lin.arm64";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    "x86_64-darwin" = {
      archSuffix = "mac.x86_64";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    "aarch64-darwin" = {
      archSuffix = "mac.arm64";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  info = systemMap.${system} or (throw "Unsupported system: ${system}");
  isDarwin = pkgs.lib.hasSuffix "darwin" system;
in
pkgs.stdenv.mkDerivation rec {
  pname = "camoufox";
  inherit version;

  src = pkgs.fetchzip {
    url = "https://github.com/daijro/camoufox/releases/download/v${version}/camoufox-${version}-${info.archSuffix}.zip";
    sha256 = info.sha256;
    stripRoot = false;
  };

  nativeBuildInputs = [
    pkgs.jq
    pkgs.makeWrapper
  ] ++ pkgs.lib.optionals (!isDarwin) [
    pkgs.autoPatchelfHook
    pkgs.wrapGAppsHook3
    pkgs.lndir
    pkgs.gtk3
  ];

  buildInputs = pkgs.lib.optionals (!isDarwin) (with pkgs; [
    gtk3
    glib
    pango
    cairo
    gdk-pixbuf
    atk
    libxkbcommon
    stdenv.cc.cc.lib
    alsa-lib
    gsettings-desktop-schemas
    fontconfig
    libglvnd
    at-spi2-atk
    dbus
    librsvg
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libXcursor
    xorg.libXi
    xorg.libXext
    xorg.libxcb
    mesa
    libpulseaudio
    pipewire
    ffmpeg
  ]);

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${pname}
    cp -r ./* $out/lib/${pname}/
    chmod +x $out/lib/${pname}/camoufox-bin || true

    mkdir -p $out/bin

    # Create a wrapper that sets the Firefox app directory correctly
    makeWrapper $out/lib/${pname}/camoufox-bin $out/bin/camoufox-bin \
      --set MOZ_APP_LAUNCHER camoufox \
      --set GDK_BACKEND x11 \
      --prefix LD_LIBRARY_PATH : "$out/lib/${pname}" \
      --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
      "''${gappsWrapperArgs[@]}"

    # Wrapper for the camoufox launcher script (if it exists and is a script)
    if [ -f $out/lib/${pname}/camoufox ] && file $out/lib/${pname}/camoufox | grep -q "script"; then
      makeWrapper $out/lib/${pname}/camoufox $out/bin/camoufox \
        --set MOZ_APP_LAUNCHER camoufox \
        --set GDK_BACKEND x11 \
        --prefix LD_LIBRARY_PATH : "$out/lib/${pname}" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
        "''${gappsWrapperArgs[@]}"
    else
      # If camoufox is a binary, wrap it too
      makeWrapper $out/lib/${pname}/camoufox $out/bin/camoufox \
        --set MOZ_APP_LAUNCHER camoufox \
        --set GDK_BACKEND x11 \
        --prefix LD_LIBRARY_PATH : "$out/lib/${pname}" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
        "''${gappsWrapperArgs[@]}"
    fi

    runHook postInstall
  '';

  gappsWrapperArgs = pkgs.lib.optionals (!isDarwin) [
    "--prefix XDG_DATA_DIRS : ${pkgs.gsettings-desktop-schemas}/share"
    "--prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share"
  ];

  meta = with pkgs.lib; {
    description = "A stealthy, minimalistic, custom build of Firefox for web scraping";
    homepage = "https://github.com/daijro/camoufox";
    license = licenses.mit;
    platforms = builtins.attrNames systemMap;
    mainProgram = "camoufox";
  };
}
