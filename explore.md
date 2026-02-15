# Codebase Overview

This is a **Project IDX community template** for bootstrapping Flutter projects via `flutter create`. It provides a configurable UI for users to customize their Flutter project setup directly within [Project IDX](https://idx.dev).

## Architecture

```
┌─────────────────────┐
│  idx-template.json  │  ← Template metadata & UI params (shown to users)
└────────┬────────────┘
         │ feeds params into
         ▼
┌─────────────────────┐
│  idx-template.nix   │  ← Bootstrap logic (runs `flutter create` with params)
└────────┬────────────┘
         │ copies
         ▼
┌─────────────────────┐
│      dev.nix        │  ← Dev environment config (workspace runtime)
└─────────────────────┘

┌─────────────────────┐
│ scripts/update.dart │  ← Code-gen: regenerates idx-template.json from
│ + Makefile          │     `flutter create --list-samples`
└─────────────────────┘
```

## File-by-File Breakdown

### `idx-template.json` — Template Definition
Defines how the template appears in the IDX "new project" UI. It exposes **4 parameters**:

| Param | Type | Purpose |
|-------|------|---------|
| `template` | enum | `app`, `module`, `package`, `plugin`, `plugin_ffi`, `skeleton` |
| `sample` | enum | ~500+ Flutter widget samples (or "None") |
| `blank` | boolean | Skip boilerplate comments (`-e` flag) |
| `platforms` | text | Comma-separated: `web,android,ios,linux,macos,windows` |

The massive `sample` options list is **auto-generated** (see below).

### `idx-template.nix` — Bootstrap Script
Executes when a new workspace is created. Key logic:

```nix
flutter create "$out" \
  --template="${template}" \
  --platforms="${platforms}" \
  ${if sample == "none" then "" else "--sample=${sample}"} \
  ${if blank then "-e" else ""}
```

Then copies `dev.nix` into the generated project's `.idx/` directory.

### `dev.nix` — Workspace Runtime Config
Configures the **running development environment**:

- **Packages**: `firebase-tools`, JDK, `unzip`
- **PATH**: Adds Flutter SDK, Dart pub cache
- **Extensions**: Installs Flutter & Dart VS Code extensions
- **Previews**: Configures both **web** and **Android emulator** previews with `flutter run --machine`
- **onCreate**: Runs `flutter pub get` on first launch

### `scripts/update.dart` + `Makefile` — Code Generation
A maintenance pipeline to keep the sample list current:

```makefile
# Makefile
flutter create --list-samples=scripts/assets/samples.json  # dump all samples
dart run scripts/update.dart                                 # regenerate JSON
```

`update.dart` reads the samples JSON, maps each `{id, element}` entry into the enum options format, and writes the full `idx-template.json`.

## Notable Observations

1. **Commented-out params** in `update.dart` suggest `org`, `project-name`, and `project-description` were considered but not exposed.

2. **Inconsistency**: `idx-template.json` has `"virtualization": "true"` (string), while `update.dart` generates `"virtualization": true` (boolean).

3. **Icon URL mismatch**: The checked-in `idx-template.json` uses a different icon URL (`gstatic.com/...`) than what `update.dart` generates (`storage.googleapis.com/...`), suggesting the JSON was manually edited after generation.

4. **The sample list is enormous** (~500+ entries), covering `material`, `cupertino`, `widgets`, `rendering`, `painting`, `dart_ui`, and other Flutter libraries — all auto-generated from Flutter's own sample registry.

5. **Both Nix files target `stable-25.05`** channel, keeping the bootstrap and runtime environments consistent.
