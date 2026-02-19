# .idx/scripts/enable-slint.nix
# Load this with: nix-shell .idx/scripts/enable-slint.nix
{ pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  }
}:

let
  overlays = import ../overlays/default.nix;
  extendedPkgs = builtins.foldl' (p: overlay: p.extend overlay) pkgs overlays;

  slintAndroid = import ../modules/slint-android {
    pkgs = extendedPkgs;
    lib = pkgs.lib;
    system = pkgs.stdenv.system;
  };
in
pkgs.mkShell ({
  name = "slint-android-dev";

  buildInputs = slintAndroid.packages ++ (with extendedPkgs; [
    git
    curl
    wget
    jq
    tree
  ]);

  shellHook = ''
    ${slintAndroid.shellHook}
  '';
} // slintAndroid.env)
