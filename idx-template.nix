# Bootstrap script for VNC template creation.
# Runs `flutter create` with user-selected params from idx-template.json,
# then copies the VNC infrastructure and dev.nix into the generated project.
{ pkgs
, sample ? "none"
, template ? "app"
, blank ? false
, platforms ? "web"
, ...
}:
let
  # Build Camoufox from the local flake definition (same derivation as camoufox/flake.nix)
  camoufox = pkgs.stdenv.mkDerivation rec {
    pname = "camoufox";
    version = "135.0.1-beta.24";

    src = pkgs.fetchzip {
      url = "https://github.com/daijro/camoufox/releases/download/v${version}/camoufox-${version}-lin.x86_64.zip";
      sha256 = "sha256-k5t12L5q0RG8Zun0SAjGthYQXUcf+xVHvk9Mknr97QY=";
      stripRoot = false;
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.wrapGAppsHook3
      pkgs.lndir
      pkgs.jq
      pkgs.gtk3
    ];

    buildInputs = with pkgs; [
      gtk3 glib pango cairo gdk-pixbuf atk libxkbcommon
      stdenv.cc.cc.lib alsa-lib gsettings-desktop-schemas
      fontconfig libglvnd at-spi2-atk dbus librsvg
      libx11 libxcomposite libxdamage libxfixes
      libxrandr libxrender libxtst
    ];

    gappsWrapperArgs = [
      "--prefix XDG_DATA_DIRS : ${pkgs.gsettings-desktop-schemas}/share"
      "--prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share"
      "--prefix LD_LIBRARY_PATH : ${placeholder "out"}/lib/${pname}"
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/${pname}
      cp -r ./* $out/lib/${pname}/
      mkdir -p $out/bin
      ln -s $out/lib/${pname}/camoufox $out/bin/camoufox
      ln -s $out/lib/${pname}/camoufox-bin $out/bin/camoufox-bin
      runHook postInstall
    '';
  };
in
{
  channel = "unstable";

  packages = [
    pkgs.curl
    pkgs.gnutar
    pkgs.xz
    pkgs.git
    pkgs.busybox
    pkgs.nix 
    # pkgs.tigervnc
    # pkgs.fluxbox
    # pkgs.python313Packages.websockify
    # pkgs.novnc

    # # Desktop environment
    # pkgs.dbus
    # pkgs.xterm
    # pkgs.xdotool
    # pkgs.xorg.xrdb

    # Browser dependencies
    pkgs.chromium

  ];

  bootstrap = ''
    # 1. Create Flutter project
    # flutter create "$out" \
    #  --template="${template}" \
    #  --platforms="${platforms}" \
    #  ${if sample == "none" then "" else "--sample=${sample}"} \
    #  ${if blank then "-e" else ""}

    # 2. Copy Chromium binary into $out so it's available at runtime
    mkdir -p "$out"/bin
    ln -sf ${pkgs.chromium}/bin/chromium "$out"/bin/chromium

    # 2b. Link Camoufox binary into $out/bin
    ln -sf ${camoufox}/bin/camoufox "$out"/bin/camoufox
    ln -sf ${camoufox}/bin/camoufox-bin "$out"/bin/camoufox-bin

    mkdir -p "$out"/.idx
    install -m 644 ${./dev.nix} "$out"/.idx/dev.nix

    # 3. Copy VNC infrastructure — root files
    install -m 644 ${./config.env} "$out"/config.env
    install -m 755 ${./lib.sh} "$out"/lib.sh
    install -m 644 ${./flake.nix} "$out"/flake.nix
    install -m 644 ${./justfile} "$out"/justfile

    # 4. Shell scripts
    install -m 755 ${./start-with-vnc.sh} "$out"/start-with-vnc.sh
    install -m 755 ${./start-vpn.sh} "$out"/start-vpn.sh
    install -m 755 ${./stop-vnc.sh} "$out"/stop-vnc.sh
    install -m 755 ${./stop-vpn.sh} "$out"/stop-vpn.sh
    install -m 755 ${./status-vnc.sh} "$out"/status-vnc.sh

    # 5. Scripts directory
    mkdir -p "$out"/scripts
    install -m 755 ${./scripts/setup-fonts.sh} "$out"/scripts/setup-fonts.sh
    install -m 755 ${./scripts/setup-dbus.sh} "$out"/scripts/setup-dbus.sh
    install -m 755 ${./scripts/setup-gpu-env.sh} "$out"/scripts/setup-gpu-env.sh
    install -m 755 ${./scripts/setup-fluxbox.sh} "$out"/scripts/setup-fluxbox.sh
    install -m 755 ${./scripts/start-vnc-server.sh} "$out"/scripts/start-vnc-server.sh

    # 6. Config directory
    mkdir -p "$out"/config/fluxbox
    install -m 644 ${./config/Xresources} "$out"/config/Xresources
    install -m 644 ${./config/proxychains.conf.template} "$out"/config/proxychains.conf.template
    install -m 644 ${./config/fluxbox/menu.template} "$out"/config/fluxbox/menu.template
    install -m 644 ${./config/fluxbox/keys.template} "$out"/config/fluxbox/keys.template
    install -m 644 ${./config/fluxbox/init} "$out"/config/fluxbox/init
    install -m 755 ${./config/fluxbox/startup} "$out"/config/fluxbox/startup

    # 7. Wrappers
    mkdir -p "$out"/wrappers
    install -m 755 ${./wrappers/google-chrome.sh} "$out"/wrappers/google-chrome.sh

    # 8. Camoufox launchers
    mkdir -p "$out"/camoufox
    install -m 644 ${./camoufox/flake.nix} "$out"/camoufox/flake.nix
    install -m 644 ${./camoufox/README.md} "$out"/camoufox/README.md
    install -m 755 ${./camoufox/browser-1.sh} "$out"/camoufox/browser-1.sh
    install -m 755 ${./camoufox/browser-2.sh} "$out"/camoufox/browser-2.sh

    # 9. VPN config examples
    install -m 644 ${./v2ray-client.json.example} "$out"/v2ray-client.json.example
    install -m 644 ${./v2ray-client-reality.json.example} "$out"/v2ray-client-reality.json.example

    chmod -R u+w "$out"
  '';
}
