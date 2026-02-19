# .idx/overlays/default.nix
[
  (import ./android.nix)
  (import ./fenix.nix)
  (import ./rust.nix)
]
