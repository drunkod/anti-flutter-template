#!/usr/bin/env bash

set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ] || [ ! -f "$SCRIPT_DIR/config.env" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=../lib.sh
source "$SCRIPT_DIR/lib.sh"

setup_fluxbox() {
    echo "🖥️  Configuring Fluxbox..."

    mkdir -p "$HOME/.fluxbox"

    TERMINAL_BIN="$(
        command -v xterm 2>/dev/null ||
        command -v x-terminal-emulator 2>/dev/null ||
        command -v uxterm 2>/dev/null ||
        echo "xterm"
    )"
    SHELL_BIN="$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "/bin/sh")"

    # Debug log file for menu clicks
    DBGLOG="$HOME/.fluxbox-debug.log"

    # Ensure browser command exists before the Antigravity build creates its symlink.
    mkdir -p "$(dirname "$BROWSER_CMD")"
    if [ ! -x "$BROWSER_CMD" ]; then
        FALLBACK_BROWSER="$(
            command -v google-chrome 2>/dev/null ||
            command -v chromium 2>/dev/null ||
            command -v chromium-browser 2>/dev/null ||
            command -v xdg-open 2>/dev/null ||
            true
        )"
        if [ -n "$FALLBACK_BROWSER" ] && [ -x "$FALLBACK_BROWSER" ]; then
            ln -sf "$FALLBACK_BROWSER" "$BROWSER_CMD"
        fi
    fi

    # ── Menu (heredoc with debug logging) ──
    cat > "$HOME/.fluxbox/menu" <<MENUEOF
[begin] (Antigravity Desktop)
  [submenu] (Terminal)
    [exec] (XTerm) {echo "\$(date): EXEC xterm | DISPLAY=\$DISPLAY PATH=\$PATH" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 2>> ${DBGLOG}}
    [exec] (XTerm Dark) {echo "\$(date): EXEC xterm-dark" >> ${DBGLOG}; ${TERMINAL_BIN} -bg black -fg white -fa "DejaVu Sans Mono" -fs 11 2>> ${DBGLOG}}
    [exec] (XTerm Large) {echo "\$(date): EXEC xterm-large" >> ${DBGLOG}; ${TERMINAL_BIN} -bg black -fg green -fa "DejaVu Sans Mono" -fs 14 2>> ${DBGLOG}}
    [exec] (Bash Login) {echo "\$(date): EXEC bash-login" >> ${DBGLOG}; ${TERMINAL_BIN} -e ${SHELL_BIN} --login 2>> ${DBGLOG}}
  [end]
  [submenu] (Web Browser)
    [exec] (Chromium) {echo "\$(date): EXEC browser cmd=${BROWSER_CMD}" >> ${DBGLOG}; ls -la ${BROWSER_CMD} >> ${DBGLOG} 2>&1; ${BROWSER_CMD} 2>> ${DBGLOG}}
    [exec] (Chromium — google.com) {echo "\$(date): EXEC browser google" >> ${DBGLOG}; ${BROWSER_CMD} https://www.google.com 2>> ${DBGLOG}}
    [exec] (Chromium — check IP) {echo "\$(date): EXEC browser ifconfig" >> ${DBGLOG}; ${BROWSER_CMD} https://ifconfig.me 2>> ${DBGLOG}}
  [end]
  [submenu] (Tools)
    [exec] (File Listing) {echo "\$(date): EXEC file-listing" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'ls -la ~; echo "---"; read -rp "Press Enter..."' 2>> ${DBGLOG}}
    [exec] (Disk Usage) {echo "\$(date): EXEC disk-usage" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'df -h; echo "---"; read -rp "Press Enter..."' 2>> ${DBGLOG}}
    [exec] (Processes) {echo "\$(date): EXEC processes" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'ps aux; echo "---"; read -rp "Press Enter..."' 2>> ${DBGLOG}}
  [end]
  [submenu] (VPN)
    [exec] (VPN Status) {echo "\$(date): EXEC vpn-status" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -hold -e ${SHELL_BIN} -lc 'cd ${SCRIPT_DIR} && ${SHELL_BIN} status-vnc.sh' 2>> ${DBGLOG}}
    [exec] (Check VPN IP) {echo "\$(date): EXEC vpn-ip" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -hold -e ${SHELL_BIN} -lc 'echo "=== VPN IP ==="; curl -s --connect-timeout 5 --proxy socks5h://127.0.0.1:${SOCKS_PORT} https://ifconfig.me 2>/dev/null || echo FAILED; echo; echo "=== Direct IP ==="; env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo FAILED; echo' 2>> ${DBGLOG}}
    [exec] (VPN Log) {echo "\$(date): EXEC vpn-log" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'tail -50f ${VPN_LOG_FILE}' 2>> ${DBGLOG}}
    [exec] (App Log) {echo "\$(date): EXEC app-log" >> ${DBGLOG}; ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'tail -50f ${LOG_FILE}' 2>> ${DBGLOG}}
  [end]
  [separator]
  [submenu] (Fluxbox)
    [workspaces] (Workspaces)
    [submenu] (Styles)
      [stylesdir] (/usr/share/fluxbox/styles)
      [stylesdir] (~/.fluxbox/styles)
    [end]
    [config] (Configure)
    [reconfig] (Reconfigure)
    [restart] (Restart Fluxbox)
  [end]
  [separator]
  [exit] (Exit Fluxbox)
[end]
MENUEOF

    # ── Keys (heredoc, like original working code) ──
    cat > "$HOME/.fluxbox/keys" <<KEYSEOF
# Ctrl+Alt+T = terminal
Control Mod1 T :Exec ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -bg black -fg white
# Ctrl+Alt+B = browser
Control Mod1 B :Exec ${BROWSER_CMD}

# Window management
Mod1 Tab :NextWindow {groups} (workspace=[current])
Mod1 Shift Tab :PrevWindow {groups} (workspace=[current])
Mod1 F4 :Close
Mod1 F5 :KillWindow
Mod1 F9 :Minimize
Mod1 F10 :Maximize

# Titlebar: drag to move, right-drag to resize
OnTitlebar Mouse1 :MacroCmd {Raise} {Focus} {StartMoving}
OnTitlebar Mouse3 :MacroCmd {Raise} {Focus} {StartResizing NearestCorner}

# Desktop: right-click = menu, middle-click = workspace menu, scroll = switch workspace
OnDesktop Mouse3 :RootMenu
OnDesktop Mouse2 :WorkspaceMenu
OnDesktop Mouse4 :PrevWorkspace
OnDesktop Mouse5 :NextWorkspace

# Window snapping (Super+arrow)
Mod4 Left  :MacroCmd {ResizeTo 50% 100%} {MoveTo 0 0 Left}
Mod4 Right :MacroCmd {ResizeTo 50% 100%} {MoveTo 0 0 Right}
Mod4 Up    :Maximize
KEYSEOF

    # ── Init ──
    cat > "$HOME/.fluxbox/init" <<'INITEOF'
session.screen0.toolbar.visible: true
session.screen0.toolbar.placement: BottomCenter
session.screen0.toolbar.widthPercent: 100
session.screen0.toolbar.height: 24
session.screen0.toolbar.tools: prevworkspace, workspacename, nextworkspace, iconbar, systemtray, clock
session.screen0.workspaces: 4
session.screen0.workspaceNames: Main,Web,Term,Misc
session.screen0.tab.placement: TopLeft
session.screen0.tab.width: 64
session.screen0.window.focus.alpha: 255
session.screen0.window.unfocus.alpha: 200
session.screen0.menu.alpha: 230
session.menuFile: ~/.fluxbox/menu
session.keyFile: ~/.fluxbox/keys
session.configVersion: 13
INITEOF

    # ── Xresources ──
    cp "$SCRIPT_DIR/config/Xresources" "$HOME/.Xresources"

    # ── Proxychains ──
    render_template \
        "$SCRIPT_DIR/config/proxychains.conf.template" \
        "$PROXYCHAINS_CONF" \
        "SOCKS_PORT=$SOCKS_PORT"

    echo "   ✅ Fluxbox menu, keys, and theme configured"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    setup_fluxbox
fi
