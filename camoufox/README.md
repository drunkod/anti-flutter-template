## Camoufox Launchers

This folder contains two wrapper scripts used by Fluxbox:

- `browser-1.sh` launches Camoufox with profile `~/.camoufox/profile-1`
- `browser-2.sh` launches Camoufox with profile `~/.camoufox/profile-2`

Using separate profiles allows both instances to run at the same time.

The launchers also force software rendering and disable Firefox sandbox layers by default
to improve compatibility in restricted container environments (IDX/VNC).
