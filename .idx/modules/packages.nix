# .idx/modules/packages.nix
{ pkgs, lib }:

let
  basePackages = with pkgs; [
    git
    curl
    wget
    jq
    tree
    file
    which
    ripgrep
    fd
    bat

    gcc
    gnumake
    pkg-config
  ];
in
  basePackages
