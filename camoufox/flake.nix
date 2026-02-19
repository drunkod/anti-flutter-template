{
  description = "A flake for packaging the Camoufox binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      camoufox-pkg = pkgs.stdenv.mkDerivation rec {
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
          libx11
          libxcomposite
          libxdamage
          libxfixes
          libxrandr
          libxrender
          libxtst
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

        meta = with pkgs.lib; {
          description = "A stealthy, minimalistic, custom build of Firefox for web scraping";
          homepage = "https://github.com/daijro/camoufox";
          license = licenses.mit;
          platforms = platforms.linux;
          mainProgram = "camoufox";
        };
      };

    in
    {
      packages.${system} = {
        camoufox = camoufox-pkg;
        default = camoufox-pkg;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ self.packages.${system}.camoufox ];
      };
    };
}
