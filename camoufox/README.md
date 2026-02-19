## Camoufox Launchers

This folder contains:

- `flake.nix` to package Camoufox as an external flake dependency
- two wrapper scripts used by Fluxbox

- `browser-1.sh` launches Camoufox with profile `~/.camoufox/profile-1`
- `browser-2.sh` launches Camoufox with profile `~/.camoufox/profile-2`

Using separate profiles allows both instances to run at the same time.

The launchers use the wrapped `camoufox` binary from the Nix package output so GTK/GSettings
runtime paths from `wrapGAppsHook` are applied consistently.
