{
  description = "Antigravity with Git support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      terminalDeps = with pkgs; [
        bashInteractive
        coreutils
        gnugrep
        gnused
        findutils
        procps
        which
        less
        tree
        file
        util-linux
        ncurses
        git
      ];

      launcherDeps = with pkgs; [
        dejavu_fonts
        liberation_ttf
        noto-fonts
        fontconfig
        fluxbox
        tigervnc
        dbus
        psmisc
        wget
        unzip
        xray
        proxychains-ng
        curl
        xterm
        xdotool
        xorg.xrdb
        python3Packages.websockify
      ];

      fullPath = pkgs.lib.makeBinPath terminalDeps;

      chromiumFlags = builtins.concatStringsSep " " [
        "--no-sandbox"
        "--disable-gpu"
        "--disable-gpu-compositing"
        "--disable-gpu-sandbox"
        "--disable-software-rasterizer"
        "--disable-dev-shm-usage"
        "--disable-vulkan"
        "--disable-features=VizDisplayCompositor,Vulkan,UseSkiaRenderer"
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=x11"
        "--disable-accelerated-2d-canvas"
        "--disable-accelerated-video-decode"
        "--disable-breakpad"
      ];

      googleChromeWrapper = pkgs.replaceVars ./wrappers/google-chrome.sh {
        chromium = "${pkgs.chromium}/bin/chromium";
        inherit chromiumFlags;
      };
    in
    {
      packages.${system}.default = pkgs.symlinkJoin {
        name = "antigravity-wrapped";
        paths = [ pkgs.antigravity ];
        nativeBuildInputs = [ pkgs.makeWrapper ];

        postBuild = ''
          mkdir -p $out/bin

          ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/bash
          ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/sh
          ln -sf ${pkgs.git}/bin/git $out/bin/git

          install -m 755 ${googleChromeWrapper} $out/bin/google-chrome
          ln -sf google-chrome $out/bin/xdg-open

          for name in google-chrome-stable chromium chromium-browser chrome; do
            ln -sf google-chrome $out/bin/$name
          done

          wrapProgram $out/bin/antigravity \
            --prefix PATH : "$out/bin:${fullPath}" \
            --set-default SHELL "$out/bin/bash" \
            --set-default CHROME_PATH "$out/bin/google-chrome" \
            --set-default CHROME_EXECUTABLE "$out/bin/google-chrome" \
            --set-default CHROME_BIN "$out/bin/google-chrome" \
            --set-default BROWSER "$out/bin/google-chrome" \
            --set VK_ICD_FILENAMES "" \
            --set LIBVA_DRIVER_NAME "null" \
            --set MESA_LOADER_DRIVER_OVERRIDE "swrast" \
            --set GALLIUM_DRIVER "llvmpipe" \
            --unset XDG_CURRENT_DESKTOP \
            --unset DESKTOP_SESSION
        '';

        meta = pkgs.antigravity.meta // {
          mainProgram = "antigravity";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = terminalDeps ++ launcherDeps;

        shellHook = ''
          export NIXPKGS_ALLOW_UNFREE=1
        '';
      };
    };
}
