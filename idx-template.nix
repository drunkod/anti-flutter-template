# Bootstrap script for VNC template creation.
# Runs `flutter create` with user-selected params from idx-template.json,
# then copies the VNC infrastructure and dev.nix into the generated project.
{ pkgs
, sample ? "none"
, template ? "app"
, blank ? false
, platforms ? "web"
, ...
}:
let
  # Re-import nixpkgs with allowUnfree for proprietary packages (e.g. antigravity)
  pkgsUnfree = import pkgs.path {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

  # Build Camoufox from the shared package definition
  camoufox = import ./camoufox/package.nix { inherit pkgs; };
in
{
  channel = "unstable";

  packages = [
    pkgs.curl
    pkgs.gnutar
    pkgs.xz
    pkgs.git
    pkgs.busybox
    pkgs.nix 
    # pkgs.tigervnc
    # pkgs.fluxbox
    # pkgs.python313Packages.websockify
    # pkgs.novnc

    # # Desktop environment
    # pkgs.dbus
    # pkgs.xterm
    # pkgs.xdotool
    # pkgs.xorg.xrdb

    # Browser dependencies
    pkgs.chromium

    pkgsUnfree.antigravity

  ];

  bootstrap = ''
    # 1. Create Flutter project
    # flutter create "$out" \
    #  --template="${template}" \
    #  --platforms="${platforms}" \
    #  ${if sample == "none" then "" else "--sample=${sample}"} \
    #  ${if blank then "-e" else ""}

    # 2. Copy all runtime files from out/ (mirrors $out structure)
    cp -r ${./out}/. "$out"/
    chmod -R u+w "$out"

    # 3. Copy flake.nix (stays at repo root, deployed separately)
    install -m 644 ${./flake.nix} "$out"/flake.nix

    # 4. Copy camoufox files
    mkdir -p "$out"/camoufox
    install -m 644 ${./camoufox/flake.nix} "$out"/camoufox/flake.nix
    install -m 644 ${./camoufox/README.md} "$out"/camoufox/README.md
    install -m 755 ${./camoufox/browser-1.sh} "$out"/camoufox/browser-1.sh
    install -m 755 ${./camoufox/browser-2.sh} "$out"/camoufox/browser-2.sh

    # 5. Link binaries into $out/bin
    mkdir -p "$out"/bin
    ln -sf ${pkgs.chromium}/bin/chromium "$out"/bin/chromium
    ln -sf ${camoufox}/bin/camoufox "$out"/bin/camoufox
    ln -sf ${camoufox}/bin/camoufox-bin "$out"/bin/camoufox-bin
    ln -sf ${pkgsUnfree.antigravity}/bin/antigravity "$out"/bin/antigravity
  '';
}
