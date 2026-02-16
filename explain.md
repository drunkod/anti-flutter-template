# Template Sync Notes

## Why generated projects missed files

`idx-template.nix` did not copy:

- `scripts/start-kasm-server.sh`
- the `kasmvnc/` folder (external local flake)

So new projects created from the template did not contain those files, even though they exist in this repository.

## Fix applied

`idx-template.nix` now copies:

- `scripts/start-kasm-server.sh`
- all files from `kasmvnc/` into generated project `./kasmvnc/`

This ensures generated projects include the external KasmVNC flake and the new Kasm startup flow.
