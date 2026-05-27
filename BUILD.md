# Build & run

This project is a Swift/AppKit app generated from `Project.yml` via
[xcodegen](https://github.com/yonaskolb/XcodeGen) and built with `xcodebuild`.
The `Notepad.xcodeproj/` directory is **regenerated on every build** — never
edit it by hand; edit `Project.yml` instead.

## Prerequisites

| Tool       | Install                            | Why                       |
|------------|------------------------------------|---------------------------|
| Xcode      | App Store                          | Provides `xcodebuild` + SDK |
| xcodegen   | `brew install xcodegen`            | Generates `.xcodeproj`    |

The first time you build, also run once:

```
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -license accept     # if not yet accepted
```

## Quick start

```
./build-project.sh             # Debug build
./build-project.sh -o          # build + launch the app
./build-project.sh -c Release  # Release build
./build-project.sh -t          # also run the XCTest suite
```

Outputs:

- `build/Build/Products/<Config>/Notepad.app` — the compiled bundle
- `buildlog.txt` — full `xcodebuild` log (last 20 lines printed on failure)

`-h` prints the embedded usage block.

## Project structure

```
Notepad/
  App/           NSApplication / document setup
  Window/        NotepadWindowController, custom window chrome
  Dialogs/       Find, Replace, Font, Go-To-Line, custom file browser, etc.
  Theme/         Colors.swift, Fonts.swift, Metrics.swift — pixel-faithful values
  Menu/          Menu builders for both in-window and macOS top menu bar
NotepadTests/    XCTest suite
Project.yml      xcodegen spec — source of truth for targets/settings
PRD.md           Authoritative product spec
PROMPT.md        Single-worker Ralph iteration prompt
PROMPT-parallel.md  Parallel-worker Ralph iteration prompt
ralph*.sh        Ralph automation loop
```

## Running the app manually

```
open build/Build/Products/Debug/Notepad.app
```

Or double-click the bundle in Finder. On first launch macOS Gatekeeper may
warn about an unsigned developer — right-click → Open to bypass once. (App
Store distribution will require signing + notarization — see future
`APP-STORE.md`.)

## Cleaning

```
rm -rf build Notepad.xcodeproj buildlog.txt
```

`build/` and the regenerated project will be recreated by the next
`./build-project.sh`.

## Troubleshooting

- **`xcodegen: command not found`** — `brew install xcodegen`.
- **`xcodebuild: error: SDK "macosx" cannot be located`** — run
  `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
- **Build fails with `Notepad.xcodeproj` errors after editing `Project.yml`** —
  delete `Notepad.xcodeproj/` and re-run `./build-project.sh`. The script
  regenerates it.
- **"Damaged app, move to Trash"** when running the built `.app` from
  Finder — it is unsigned. Right-click the bundle → Open, then confirm.
