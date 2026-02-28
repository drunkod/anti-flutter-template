# VNC + VPN Workspace Environment
{ pkgs, ... }: {
  channel = "unstable";

  packages = [
    pkgs.psmisc

    # Fonts
    pkgs.fontconfig
    pkgs.dejavu_fonts
    pkgs.liberation_ttf
    pkgs.noto-fonts

    # VPN / networking
    pkgs.xray
    pkgs.proxychains-ng
    pkgs.wget
    pkgs.dbus
    pkgs.tigervnc
    pkgs.fluxbox
    pkgs.xterm
    pkgs.xdotool
    pkgs.xorg.xrdb
    pkgs.python313Packages.websockify
    pkgs.novnc
    pkgs.unzip
  ];

  env = {};

  idx = {
    extensions = [
      "google.gemini-cli-vscode-ide-companion"
    ];

    workspace = {
      onCreate = {
        default.openFiles = [ "README.md" ];
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
