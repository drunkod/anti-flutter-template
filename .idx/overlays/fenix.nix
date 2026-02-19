# .idx/overlays/fenix.nix
final: prev: {
  fenixPkgs = prev.callPackage (prev.fetchgit {
    url = "https://github.com/nix-community/fenix";
    rev = "1d3600dda5c27ddbc9c424bb4edae744bdb9b14d";
    sha256 = "sha256-RUR2yXYbKSoDvI/JdH0AvojFjhCfxBXOA/BtGUpaoR0=";
  }) { };
}
