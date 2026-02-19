# .idx/modules/environment.nix
{ pkgs, lib }:

let
  currentPath = builtins.getEnv "PWD";
in {
  CARGO_HOME = "${currentPath}/.cargo-home";

  LD_LIBRARY_PATH = lib.makeLibraryPath (with pkgs; [
    wayland
    libxkbcommon
    fontconfig
  ]);
}
