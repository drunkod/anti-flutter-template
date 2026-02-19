# .idx/dev.nix
{ pkgs, lib, config, ... }:

let
  overlays = import ./overlays/default.nix;
  extendedPkgs = builtins.foldl' (p: overlay: p.extend overlay) pkgs overlays;

  packages = import ./modules/packages.nix {
    pkgs = extendedPkgs;
    inherit lib;
  };

  environment = import ./modules/environment.nix {
    pkgs = extendedPkgs;
    inherit lib;
  };

  previews = import ./modules/previews.nix {
    pkgs = extendedPkgs;
  };

  workspace = import ./modules/workspace.nix {
    pkgs = extendedPkgs;
  };
in {
  imports = [
    {
      channel = "stable-25.05";
      packages = packages;
      env = environment;
    }
    previews
    workspace
  ];
}
