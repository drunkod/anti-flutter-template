{
  description = "VNC Browser Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # External Camoufox flake from local folder.
    camoufox = {
      url = "path:./camoufox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, camoufox }:
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
        "--js-flags=--jitless"
      ];

      googleChromeWrapper = pkgs.replaceVars ./wrappers/google-chrome.sh {
        chromium = "${pkgs.chromium}/bin/chromium";
        inherit chromiumFlags;
      };

      camoufoxPkg = camoufox.packages.${system}.camoufox;

      camoufoxBrowser1Wrapper = pkgs.replaceVars ./camoufox/browser-1.sh {
        camoufoxBinary = "${camoufoxPkg}/bin/camoufox";
      };

      camoufoxBrowser2Wrapper = pkgs.replaceVars ./camoufox/browser-2.sh {
        camoufoxBinary = "${camoufoxPkg}/bin/camoufox";
      };
    in
    {
      packages.${system}.default = pkgs.symlinkJoin {
        name = "vnc-browser-env";
        paths = [ camoufoxPkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];

        postBuild = ''
          mkdir -p $out/bin

          ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/bash
          ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/sh
          ln -sf ${pkgs.git}/bin/git $out/bin/git

          install -m 755 ${googleChromeWrapper} $out/bin/google-chrome
          ln -sf google-chrome $out/bin/xdg-open
          ln -sf google-chrome $out/bin/browser

          for name in google-chrome-stable chromium chromium-browser chrome; do
            ln -sf google-chrome $out/bin/$name
          done

          install -m 755 ${camoufoxBrowser1Wrapper} $out/bin/camoufox-browser-1
          install -m 755 ${camoufoxBrowser2Wrapper} $out/bin/camoufox-browser-2
          ln -sf camoufox-browser-1 $out/bin/camoufox1
          ln -sf camoufox-browser-2 $out/bin/camoufox2
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = terminalDeps ++ launcherDeps;

        shellHook = ''
          export NIXPKGS_ALLOW_UNFREE=1
        '';
      };
    };
}
