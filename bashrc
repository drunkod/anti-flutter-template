# Nix setup
if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  . ~/.nix-profile/etc/profile.d/nix.sh
fi

# Build directories
export TMPDIR=/tmp
export NIX_BUILD_TOP=/tmp/nix-build
export NIXPKGS_ALLOW_UNFREE=1

# Cargo setup
export CARGO_HOME=/tmp/cargo-home
