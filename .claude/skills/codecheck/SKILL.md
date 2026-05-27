---
name: codecheck
description: Triage and fix one runtime-stability defect in the Notepad codebase per iteration. Use this when running the ralph-codecheck loop, when the user reports "the app doesn't work" / "menus are empty" / "typing does nothing" / "open crashes", or any other behavioral regression where the build is green but the app misbehaves.
---

# Code stability triage

This skill is the playbook for one iteration of `ralph-codecheck.sh`. The
goal is **not** to add features, polish UI, or refactor. The goal is to
find ONE runtime defect that makes the app unusable, fix it minimally,
and prove the fix works via `./quality-check.sh -i`.

## Triage ladder (work top-down, stop at the first real hit)

Walk this list in order. Confirm each candidate by reading the actual
code — do not pattern-match on filenames or trust comments.

### 1. App entry point + window bring-up

- Is there a `main.swift` (or `@NSApplicationMain` on the delegate) that
  calls `NSApplication.shared.run()`? If not, `applicationDidFinishLaunching`
  never runs and there will be no window.
- Does `applicationDidFinishLaunching` create the window AND call
  `showWindow`/`makeKeyAndOrderFront`?
- Is `NSApp.activate(ignoringOtherApps:)` called so the new window comes
  to the front?
- Is the window's `styleMask` valid? Borderless-only windows need
  `canBecomeKey`/`canBecomeMain` overridden to `true` or the editor
  won't accept keystrokes.
- Is the window's initial frame on-screen? `NSScreen.main!` can return
  nil on a headless build; a force-unwrap there will crash.

### 2. Editor accepts input

- The text view's `isEditable` must be `true`.
- The text view's `isSelectable` must be `true`.
- The text view must be wired as the window's `firstResponder` (or
  `makeFirstResponder` called on it after the window appears).
- The text view's container must be installed in the scroll view's
  `documentView`.
- If a custom `EditorView` overrides `keyDown(with:)`, it must call
  `super.keyDown(with:)` OR `interpretKeyEvents([event])`, otherwise
  typing produces no output.

### 3. Menus are populated and wired

- `MenuBuilder.build()` returns a non-nil `NSMenu` and is assigned to
  `NSApp.mainMenu` **before** the first window is keyed.
- Each `NSMenuItem` has a non-nil `action:` selector AND a target chain
  that responds to it (delegate, window controller, or first responder).
- `validateMenuItem(_:)` either returns `true` for items that should be
  enabled, or is absent (default behavior is "enabled if responder chain
  handles selector").
- Menu items with empty action selectors (`#selector(noop)`, no method
  body, or routed to a method that doesn't exist) show as enabled but
  do nothing — these are stability defects.

### 4. Common menu commands work

The first-responder chain must reach a method for each of:
`undo:`, `redo:`, `cut:`, `copy:`, `paste:`, `delete:`,
`selectAll:`, `newDocument:`, `openDocument:`, `saveDocument:`,
`saveDocumentAs:`, `print:`, `performFindPanelAction:`. If any of these
shortcuts/menu items appear in `MenuBuilder.swift` but no responder
implements them, that's a defect.

### 5. File open / save plumbing

- `openDocument:` (or whatever the menu item triggers) must show a
  file panel AND on selection actually load the file into the editor.
- Loading a file must catch errors and surface them — a `try!` on a
  file read will crash on permission errors or missing files.
- Saving must handle the untitled case (prompt for filename) before
  writing.
- Sandboxed apps need a security-scoped bookmark or the open panel's
  granted URL; check whether `App Sandbox` is on in entitlements.

### 6. Crash-prone patterns

- Force-unwraps (`!`) on optionals that aren't unconditionally non-nil:
  - `window!` during early init.
  - `NSScreen.main!` (nil on detached sessions).
  - `try!` on any file/data load.
  - `as!` casts that don't have a control-flow guarantee.
- Strong reference cycles in closures: `self.x = { self.y() }` without
  `[weak self]`.
- Notification observers added but never removed (leaks, eventually
  double-fires).

### 7. Configuration & build wiring

- A `.swift` file exists on disk but is not in `Project.yml`'s sources
  list → won't be compiled → references to its types will fail at use
  sites that ARE compiled.
- `Info.plist` keys missing for declared behavior (e.g. document types
  declared but no `CFBundleDocumentTypes`).
- Entitlements file referenced in `Project.yml` but missing on disk.

## What is NOT a defect for this loop

- Compiler warnings (unused vars, deprecated API).
- Style nits (naming, formatting, comment quality).
- "Could be more idiomatic" rewrites.
- Performance improvements that don't fix a runtime bug.
- Adding new tests for already-working code.
- Anything that requires a PRD change.

Defer all of the above. They are not stability issues.

## Fixing

- One defect per iteration. Resist the urge to fix two while you're
  in the file.
- Minimum diff. Add or rewire the missing piece; do not refactor.
- The fix must pass `./build-project.sh` AND `./quality-check.sh -i` (exit
  0). If it doesn't, revert and write `failed:` — do not commit a
  half-fix.
- Commit message format: `codecheck: <slug> — <summary>` with 2–3 lines
  of WHY (what was broken, what symptom the user / QA harness saw).

## When to write `empty`

Only after walking the full ladder and finding nothing real. "I checked
the file names and they look fine" is not walking the ladder — read the
code of each candidate before declaring no defects.

The bar is now harder:

1. `./quality-check.sh -i` exits **0** (not just window-exists; the
   interactive rungs must pass).
2. `.quality-check/report.md` shows **`Typing rung: pass`** (not
   `skipped` — the LLM must verify it ran, not just trust silence).
3. `.quality-check/report.md` shows **`File→Open (⌘O) rung: pass`**.
4. Every menu command listed in `MenuBuilder.swift` reaches a real
   responder (verify by `grep` — for each `action:` selector, confirm
   the method exists on either the app delegate, a window controller,
   or a first-responder type).

If any of (1)–(4) fails, the loop has work to do. Only when all four
hold should you write `empty`. If (2) reports `skipped-no-ax`, do
**not** treat that as a pass — surface it as `failed:ax-not-granted`
so the human can grant accessibility and re-run the loop.
