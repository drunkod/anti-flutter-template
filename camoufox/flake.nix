{
  description = "A flake for packaging the Camoufox binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      version = "135.0.1-beta.24";

      # Per-system archive mapping: system -> { archSuffix, sha256 }
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

      supportedSystems = builtins.attrNames systemMap;

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems f;

      mkCamoufox = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          info = systemMap.${system};
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
            libx11
            libxcomposite
            libxdamage
            libxfixes
            libxrandr
            libxrender
            libxtst
          ]);

          gappsWrapperArgs = pkgs.lib.optionals (!isDarwin) [
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
            platforms = supportedSystems;
            mainProgram = "camoufox";
          };
        };

    in
    {
      packages = forAllSystems (system: rec {
        camoufox = mkCamoufox system;
        default = camoufox;
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ self.packages.${system}.camoufox ];
        };
      });
    };
}
