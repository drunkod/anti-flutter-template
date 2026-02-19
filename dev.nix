# Root entrypoint for local workspace; delegates to .idx/dev.nix
{ pkgs, lib, config, ... }:
import ./.idx/dev.nix { inherit pkgs lib config; }
