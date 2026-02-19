{
  description = "Slint Android Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      devConfig = import ./.idx/dev.nix {
        inherit pkgs;
        lib = pkgs.lib;
        config = {};
      };

      firstImport = builtins.elemAt devConfig.imports 0;
      envPackages = firstImport.packages;
      envSetup = firstImport.env;

      overlays = import ./.idx/overlays/default.nix;
      extendedPkgs = builtins.foldl' (p: overlay: p.extend overlay) pkgs overlays;

      slintAndroid = import ./.idx/modules/slint-android {
        pkgs = extendedPkgs;
        lib = pkgs.lib;
        inherit system;
      };

      slintPackages = slintAndroid.packages ++ envPackages;
      slintEnv = envSetup // slintAndroid.env;
    in {
      devShells.${system} = {
        default = pkgs.mkShell ({
          buildInputs = envPackages;

          shellHook = ''
            export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1
            ${envSetup.shellHook or ""}

            echo ""
            echo "Base Development Environment"
            echo ""
            echo "Base packages loaded"
            echo "Overlays available (Android SDK, Rust, Fenix)"
            echo ""
            echo "To load Slint Android tools:"
            echo "  nix develop .#slint"
            echo ""
          '';
        } // envSetup);

        slint = pkgs.mkShell ({
          buildInputs = slintPackages;

          shellHook = ''
            export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1
            ${slintAndroid.shellHook}
          '';
        } // slintEnv);
      };

      apps.${system} = {
        info = {
          type = "app";
          program = let
            infoScript = pkgs.lib.findFirst
              (p: (p.name or "") == "slint-android-info")
              null
              slintAndroid.packages;
          in "${infoScript}/bin/slint-android-info";
        };

        build = {
          type = "app";
          program = let
            buildScript = pkgs.lib.findFirst
              (p: (p.name or "") == "slint-android-build")
              null
              slintAndroid.packages;
          in "${buildScript}/bin/slint-android-build";
        };
      };

      checks.${system}.default = pkgs.runCommand "overlay-check" {} ''
        echo "Checking overlays..." > $out
        echo "Android Platform: ${extendedPkgs.androidPlatformVersion}" >> $out
        echo "Rust Toolchain: ${extendedPkgs.rustToolchain}" >> $out
        echo "Overlays loaded successfully" >> $out
      '';

      formatter.${system} = pkgs.nixpkgs-fmt;
    };
}
