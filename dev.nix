# Antigravity + Flutter workspace config — copied into generated projects.
# Dart-only: no firebase-tools, JDK, or Android emulator.
# See: https://developers.google.com/idx/guides/customize-idx-env
{ pkgs, ... }: {
  channel = "unstable";

  packages = [
    # Antigravity VNC infrastructure
    pkgs.tigervnc
    pkgs.fluxbox
    pkgs.python312Packages.websockify
    pkgs.novnc
    pkgs.antigravity

    # Utilities (no firebase-tools, no JDK)
    pkgs.unzip
  ];

  env = {};

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
      "google.gemini-cli-vscode-ide-companion"
    ];

    workspace = {
      onCreate = {
        default.openFiles = [ ".idx/dev.nix" "README.md" ];
      };
      onStart = {};
    };

    previews = {
      enable = true;
      previews = {
        web = {
          command = [
            "bash" "-c"
            "NOVNC_PORT=$PORT ./start-with-vnc.sh"
          ];
          manager = "web";
          env = {
            PORT = "$PORT";
          };
        };
      };
    };
  };
}
