# .idx/modules/workspace.nix
{ pkgs }:

{
  idx.workspace = {
    onCreate = {
      welcome = ''
        echo ""
        echo "Development Environment Ready"
        echo ""
        echo "Overlays loaded:"
        echo "  Android SDK (${pkgs.androidPlatformVersion})"
        echo "  Rust Toolchain (with Android targets)"
        echo "  Fenix"
        echo ""
        echo "To enable Slint Android development:"
        echo "  1. Run: nix develop .#slint"
        echo ""
        echo "Available commands after loading Slint:"
        echo "  slint-android-info"
        echo "  slint-android-build"
        echo "  slint-android-run"
        echo ""
      '';
    };

    onStart = {
      info = ''
        echo "Tip: load Slint Android tools with 'nix develop .#slint'"
      '';
    };
  };
}
