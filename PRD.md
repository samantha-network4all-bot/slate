# PRD — Notepad (Windows 10 Style) for macOS

> **Audience:** This document is written for an executor LLM (Haiku-class) to follow step by step. Every design decision has been pre-resolved by the product owner. **Do not invent behavior, colors, sizes, or libraries.** If a question arises that this document does not answer, stop and ask the product owner — do not guess.

---

## 0. How to use this document

1. Read **§1 Product Overview** through **§6 Functional Specifications** once, fully, before starting.
2. Implement the project **phase by phase** in the order given in **§7 Implementation Plan**.
3. After each phase, run the phase's **Definition of Done (DoD)** checklist. **Every item must pass before moving to the next phase.**
4. If a DoD item fails, fix it in the current phase. Do not defer.
5. Do not re-order phases. Each phase depends on the previous one.
6. Do not add features that are not in this document.
7. Do not refactor previous phases unless the current phase explicitly says to.

---

## 1. Product Overview

### 1.1 What we are building
A native macOS application named **Notepad** that visually and behaviorally recreates Microsoft's Windows 10 Notepad (specifically the version 1909+ with status bar showing `Ln/Col` and encoding/EOL segments).

### 1.2 Reference image
`notepad.png` in the project root shows the visual target. The window has:
- A white title bar with "Untitled - Notepad" on the left and minimize/maximize/close buttons on the right.
- A menu bar with `File  Edit  Format  View  Help` (Alt-accelerator underlines hidden by default).
- A white text editing area.
- A status bar at the bottom showing `100%`, `Windows (CRLF)`, `UTF-8` on the right side.

### 1.3 In scope
- Pixel-faithful Win10 chrome (custom borderless `NSWindow`).
- All five menus fully functional.
- Custom recreated dialogs for Open, Save As, Font, Find, Replace, Go To Line, Page Setup, About, and the close-prompt.
- Real file I/O with UTF-8, UTF-8 BOM, UTF-16 LE, UTF-16 BE encoding detection.
- Real line-ending detection (CRLF, LF, CR) and live conversion.
- Multi-window: each document is a separate window.
- Drag-and-drop of `.txt` files onto a window opens the file.
- Registered as a `.txt` handler in `Info.plist`.
- Custom always-visible Win10-style scrollbars with arrow buttons.
- Alt-key accelerator support (underlines appear while Alt is held).
- macOS top menu bar mirrors the in-window menus.
- Both ⌘ and Ctrl keyboard shortcuts are accepted.

### 1.4 Out of scope
- Tabs (Win11 feature — explicitly excluded).
- Dark mode (always light).
- Auto-save / crash recovery.
- Spell check, syntax highlighting, regex find.
- Cloud sync, telemetry, updates.
- Bundling Windows fonts (use macOS substitutes).
- Custom app icon (use Xcode's default for now).
- A custom print dialog (use the macOS print sheet).

### 1.5 Target user
A developer or hobbyist running macOS who wants the Notepad experience without a VM.

### 1.6 Success criteria
A user can perform any task that the real Windows 10 Notepad supports, and the visual output is recognizably "Notepad" — not a Mac text editor in disguise.

---

## 2. Tech Stack (locked, do not deviate)

| Item | Choice |
| --- | --- |
| Language | Swift 5.9+ |
| UI framework | AppKit (no SwiftUI) |
| Build system | Xcode project (`.xcodeproj`) |
| Minimum macOS | 13.0 (Ventura) |
| Architecture | Universal (arm64 + x86_64) |
| Third-party deps | **None.** Standard library + AppKit only. |
| Bundle ID | `com.bimboware.notepad` |
| App display name | `Notepad` |
| Window class | `NSWindow` with `styleMask = [.borderless, .resizable, .miniaturizable]` |

---

## 3. Project Structure

Create the following file/folder layout. **Use these exact names.**

```
notepad/
├── PRD.md                          (this file)
├── notepad.png                     (reference image)
├── Notepad.xcodeproj/              (Xcode project)
└── Notepad/                        (source root)
    ├── AppDelegate.swift
    ├── Info.plist
    ├── Assets.xcassets/
    │
    ├── App/
    │   ├── DocumentController.swift     (spawns windows, tracks open docs)
    │   ├── MenuBuilder.swift            (builds macOS top menu bar)
    │   └── KeyboardShortcuts.swift      (Cmd+ and Ctrl+ acceptance)
    │
    ├── Window/
    │   ├── NotepadWindow.swift          (borderless NSWindow subclass)
    │   ├── NotepadWindowController.swift
    │   ├── TitleBarView.swift           (custom title bar)
    │   ├── TitleBarButton.swift         (min/max/close button)
    │   ├── InWindowMenuBarView.swift    (the File/Edit/... bar)
    │   ├── InWindowMenuItemView.swift   (a single menu item with optional underline)
    │   ├── StatusBarView.swift
    │   └── StatusBarSegment.swift       (clickable segment)
    │
    ├── Editor/
    │   ├── EditorView.swift             (NSTextView subclass)
    │   ├── EditorScrollView.swift       (NSScrollView subclass)
    │   ├── WinScroller.swift            (NSScroller subclass with arrow buttons)
    │   ├── DocumentState.swift          (text, dirty flag, encoding, EOL, URL)
    │   └── ZoomController.swift         (text zoom 10%–500%)
    │
    ├── Dialogs/
    │   ├── DialogWindow.swift           (base class for all modal dialogs)
    │   ├── FindDialog.swift
    │   ├── ReplaceDialog.swift
    │   ├── GoToLineDialog.swift
    │   ├── FontDialog.swift
    │   ├── PageSetupDialog.swift
    │   ├── AboutDialog.swift
    │   ├── SaveChangesPrompt.swift
    │   └── FileBrowser/
    │       ├── FileBrowserDialog.swift
    │       ├── FileBrowserSidebar.swift
    │       ├── FileBrowserList.swift
    │       └── FileBrowserBreadcrumb.swift
    │
    ├── Files/
    │   ├── EncodingDetector.swift       (BOM + heuristic detection)
    │   ├── LineEndingDetector.swift
    │   ├── DocumentReader.swift
    │   └── DocumentWriter.swift
    │
    ├── Theme/
    │   ├── Colors.swift                 (named NSColor constants)
    │   ├── Fonts.swift                  (named NSFont constants)
    │   └── Metrics.swift                (sizes, paddings)
    │
    └── Util/
        ├── AltKeyMonitor.swift          (tracks Alt pressed/released)
        └── LineColumnTracker.swift      (Ln/Col for status bar)
```

Do not create files outside this list. Do not consolidate files. The layout is part of the spec.

---

## 4. Visual Design Specifications

All values are **exact** unless explicitly noted as "approximate". Use 1pt = 1 logical point on macOS (Retina handles 2×).

### 4.1 Colors (`Theme/Colors.swift`)

```swift
enum Colors {
    static let chromeBackground   = NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1) // #FFFFFF
    static let chromeBorder       = NSColor(srgbRed: 0.84, green: 0.84, blue: 0.84, alpha: 1) // #D6D6D6
    static let chromeBorderHeavy  = NSColor(srgbRed: 0.67, green: 0.67, blue: 0.67, alpha: 1) // #ABABAB
    static let chromeText         = NSColor.black
    static let chromeTextInactive = NSColor(srgbRed: 0.67, green: 0.67, blue: 0.67, alpha: 1) // #ABABAB

    static let menuHoverBg        = NSColor(srgbRed: 0.90, green: 0.95, blue: 1.00, alpha: 1) // #E5F3FF
    static let menuActiveBg       = NSColor(srgbRed: 0.80, green: 0.91, blue: 1.00, alpha: 1) // #CCE8FF
    static let menuSeparator      = NSColor(srgbRed: 0.84, green: 0.84, blue: 0.84, alpha: 1) // #D6D6D6

    static let statusBarBg        = NSColor(srgbRed: 0.94, green: 0.94, blue: 0.94, alpha: 1) // #F0F0F0
    static let statusBarSeparator = NSColor(srgbRed: 0.84, green: 0.84, blue: 0.84, alpha: 1) // #D6D6D6

    static let editorBg           = NSColor.white
    static let editorText         = NSColor.black
    static let selectionBg        = NSColor(srgbRed: 0.00, green: 0.47, blue: 0.84, alpha: 1) // #0078D7
    static let selectionText      = NSColor.white

    static let closeButtonHover   = NSColor(srgbRed: 0.91, green: 0.07, blue: 0.14, alpha: 1) // #E81123
    static let titleBarButtonHover = NSColor(srgbRed: 0.90, green: 0.90, blue: 0.90, alpha: 1) // #E5E5E5

    static let scrollbarTrack     = NSColor(srgbRed: 0.94, green: 0.94, blue: 0.94, alpha: 1) // #F0F0F0
    static let scrollbarThumb     = NSColor(srgbRed: 0.80, green: 0.80, blue: 0.80, alpha: 1) // #CDCDCD
    static let scrollbarThumbHover = NSColor(srgbRed: 0.65, green: 0.65, blue: 0.65, alpha: 1) // #A6A6A6
    static let scrollbarArrow     = NSColor(srgbRed: 0.32, green: 0.32, blue: 0.32, alpha: 1) // #525252
}
```

### 4.2 Fonts (`Theme/Fonts.swift`)

```swift
enum Fonts {
    static let chrome       = NSFont.systemFont(ofSize: 13, weight: .regular) // SF Pro 13pt for menus/title
    static let chromeBold   = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let statusBar    = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let editorDefault = NSFont(name: "Menlo", size: 11) ?? NSFont.userFixedPitchFont(ofSize: 11)!
    static let dialogLabel  = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let dialogTitle  = NSFont.systemFont(ofSize: 13, weight: .semibold)
}
```

### 4.3 Metrics (`Theme/Metrics.swift`)

```swift
enum Metrics {
    // Title bar
    static let titleBarHeight: CGFloat = 32
    static let titleBarButtonWidth: CGFloat = 46
    static let titleBarButtonHeight: CGFloat = 32
    static let titleBarIconSize: CGFloat = 10            // for the X / _ / □ glyphs
    static let titleBarPaddingLeft: CGFloat = 12

    // Menu bar (in-window)
    static let menuBarHeight: CGFloat = 22
    static let menuItemPaddingH: CGFloat = 8

    // Status bar
    static let statusBarHeight: CGFloat = 22
    static let statusSegmentPaddingH: CGFloat = 8

    // Default window
    static let defaultWindowSize = NSSize(width: 900, height: 700)
    static let topRightInset: CGFloat = 0                 // flush to top-right; just below macOS menu bar

    // Scrollbar
    static let scrollbarThickness: CGFloat = 17           // includes track
    static let scrollbarArrowButtonHeight: CGFloat = 17   // the up/down arrow squares
    static let scrollbarMinThumbLength: CGFloat = 17
}
```

### 4.4 Title bar (`Window/TitleBarView.swift`)

```
┌──────────────────────────────────────────────────────────────┬──────┬──────┬──────┐
│ Untitled - Notepad                                           │  _   │  □   │  ✕   │
└──────────────────────────────────────────────────────────────┴──────┴──────┴──────┘
  ^ 32pt tall total                                              ^ each button 46×32pt
  Left text: SF Pro 13pt, color = chromeText                     Right-aligned, no gap between buttons
  Left padding: 12pt
```

Behavior:
- Drag anywhere on the title bar (except buttons) moves the window.
- Double-click on the title bar zooms the window (calls `performZoom:`).
- Three buttons drawn right-aligned: minimize (`_`), maximize (`□`), close (`✕`).
- Each button: 46pt wide × 32pt tall.
- Hover background: `titleBarButtonHover` (#E5E5E5) for min/max, `closeButtonHover` (#E81123) for close.
- Close button hover: background red, glyph turns white.
- Glyph is drawn programmatically (do not use SF Symbols):
  - Minimize: a horizontal line 10pt wide, centered, 1pt thick, vertically centered.
  - Maximize: a 10×10pt square outline, 1pt stroke, centered.
  - Close: two diagonal lines forming an X across a 10×10pt bounding box, 1pt stroke, centered.
- Bottom border: 1pt line in `chromeBorder` color.

### 4.5 In-window menu bar (`Window/InWindowMenuBarView.swift`)

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ File   Edit   Format   View   Help                                                 │
└────────────────────────────────────────────────────────────────────────────────────┘
  22pt tall, white background, 1pt chromeBorder line at bottom
```

Behavior:
- Each item: text horizontally padded by 8pt on each side; vertically centered.
- Hover background: `menuHoverBg` (#E5F3FF).
- Click background: `menuActiveBg` (#CCE8FF); opens dropdown.
- Dropdown: standard `NSMenu` shown via `popUp(positioning:at:in:)`.
- The accelerator letter (F, E, o, V, H) is underlined **only while the Alt key is held** (see `AltKeyMonitor`).

### 4.6 Status bar (`Window/StatusBarView.swift`)

```
┌──────────────┬──────────────────────────────────┬───────┬───────────────┬─────────┐
│ Ln 1, Col 1  │                                  │ 100%  │ Windows (CRLF) │ UTF-8  │
└──────────────┴──────────────────────────────────┴───────┴───────────────┴─────────┘
  22pt tall, statusBarBg, 1pt chromeBorder line at top
  Ln/Col left-aligned (padding 8pt)            Right segments right-aligned, 8pt padding, 1pt separator between
```

Behavior:
- Left side: `Ln N, Col M` updates live as cursor moves.
- Right side, in order from left to right: zoom %, line ending label, encoding label.
- Each right segment is clickable. Click opens an `NSMenu` popup directly above the segment:
  - **Zoom**: items `Zoom In (⌘+)`, `Zoom Out (⌘-)`, `Restore Default Zoom (⌘0)`.
  - **Line ending**: items `Windows (CRLF)`, `Unix (LF)`, `Macintosh (CR)`. Selecting one re-encodes the in-memory text and marks document dirty.
  - **Encoding**: items `UTF-8`, `UTF-8 with BOM`, `UTF-16 LE`, `UTF-16 BE`. Selecting one changes the file's encoding for the next save and marks document dirty.
- Labels:
  - Zoom: `"\(percent)%"` where `percent` is integer 100, 110, etc.
  - Line ending: `Windows (CRLF)` / `Unix (LF)` / `Macintosh (CR)` (verbatim strings).
  - Encoding: `UTF-8` / `UTF-8 with BOM` / `UTF-16 LE` / `UTF-16 BE`.

### 4.7 Custom scrollbars (`Editor/WinScroller.swift`)

- Subclass `NSScroller`. Override `drawKnobSlot(in:highlight:)` and `drawKnob()`.
- Always visible (`scrollerStyle = .legacy`, `knobStyle = .default`, `usesPredominantAxisScrolling = false`).
- Track: `scrollbarTrack` color, no border.
- Thumb (knob): solid `scrollbarThumb`, becomes `scrollbarThumbHover` while hovered or dragged. No rounded corners.
- Top end: 17×17pt arrow button drawn with an upward-pointing triangle (5pt wide × 3pt tall) in `scrollbarArrow` color.
- Bottom end: 17×17pt arrow button with a downward-pointing triangle.
- For horizontal scrollers, replace up/down with left/right.
- Clicking an arrow button scrolls one line; click-and-hold repeats every 50ms after a 300ms initial delay.

---

## 5. Application Behavior Specifications

### 5.1 Launch
- On first launch ever (no `UserDefaults` entry `lastFrame.0`), open a new untitled window at:
  - Position: top edge flush against macOS menu bar (`screen.visibleFrame.maxY`), right edge flush against screen right edge (`screen.visibleFrame.maxX`).
  - Size: 900 × 700 (`Metrics.defaultWindowSize`).
- On subsequent launches, restore the position/size of the last-closed window from `UserDefaults` key `lastFrame.0`.

### 5.2 Multi-window
- File → New (⌘N / Ctrl+N): open a new untitled window.
- File → Open (⌘O / Ctrl+O): open the file browser; on confirm, open the file in a **new** window.
- File → Exit (⌘Q / Ctrl+Q): quit the app.
- When the last window closes, the app terminates (`applicationShouldTerminateAfterLastWindowClosed` returns `true`).

### 5.3 Title bar text
- Format: `"\(displayName) - Notepad"` where:
  - `displayName` = `"Untitled"` if no file is associated, otherwise the **full absolute path** (e.g., `/Users/arjen/notes/todo.txt`).
- If document is dirty, append ` — Modified` between displayName and ` - Notepad`. Examples:
  - Clean untitled: `Untitled - Notepad`
  - Dirty untitled: `Untitled — Modified - Notepad`
  - Clean saved: `/Users/arjen/notes/todo.txt - Notepad`
  - Dirty saved: `/Users/arjen/notes/todo.txt — Modified - Notepad`

### 5.4 Dirty tracking
- A document becomes dirty the moment any character is added, removed, or modified, or the encoding/EOL is changed via the status bar.
- A document becomes clean immediately after a successful Save or Save As.
- A document is clean by default when newly opened.

### 5.5 Close prompt
- If the user closes a dirty window (X button, ⌘W, Ctrl+W, File → Exit on the last window, or ⌘Q while any window is dirty), show the `SaveChangesPrompt` dialog.
- Prompt text: exactly `"Do you want to save changes to \(displayName)?"` where `displayName` follows §5.3.
- Three buttons left-to-right: **Save**, **Don't Save**, **Cancel**.
  - **Save**: if document has a URL, save and close; if untitled, show Save As, then save and close. If user cancels Save As, return to editor (do not close).
  - **Don't Save**: close window, discard changes.
  - **Cancel**: return to editor.
- Default focused button: **Save**.
- Pressing Escape = Cancel. Pressing Return = Save.

### 5.6 Maximize button behavior
- Clicking maximize toggles macOS full screen (`window.toggleFullScreen(nil)`).
- When in full screen, the custom title bar continues to be drawn at the top (no special handling beyond what AppKit does).

### 5.7 Keyboard shortcuts
- Each shortcut accepts **both** ⌘ and Ctrl as the modifier. Implementation: in `KeyboardShortcuts.swift`, install a local event monitor that fires actions on both `.command` and `.control` modifiers for the listed keys.

| Action | Key |
| --- | --- |
| New | ⌘/Ctrl + N |
| Open | ⌘/Ctrl + O |
| Save | ⌘/Ctrl + S |
| Save As | ⌘/Ctrl + Shift + S |
| Print | ⌘/Ctrl + P |
| Exit | ⌘/Ctrl + Q |
| Undo | ⌘/Ctrl + Z |
| Redo | ⌘/Ctrl + Y |
| Cut | ⌘/Ctrl + X |
| Copy | ⌘/Ctrl + C |
| Paste | ⌘/Ctrl + V |
| Delete | Delete key |
| Find | ⌘/Ctrl + F |
| Find Next | F3 |
| Find Previous | Shift + F3 |
| Replace | ⌘/Ctrl + H |
| Go To | ⌘/Ctrl + G |
| Select All | ⌘/Ctrl + A |
| Time/Date | F5 |
| Word Wrap | (no shortcut) |
| Font | (no shortcut) |
| Zoom In | ⌘/Ctrl + Plus |
| Zoom Out | ⌘/Ctrl + Minus |
| Restore Default Zoom | ⌘/Ctrl + 0 |
| Status Bar toggle | (no shortcut) |

### 5.8 Alt accelerators
- A global event monitor (`AltKeyMonitor`) tracks the Option/Alt key.
- While Option is held:
  - The in-window menu bar repaints with underlines under the accelerator letter of each menu (F, E, o, V, H).
  - Pressing Option + that letter opens the corresponding menu.
  - Once a menu is open, pressing the underlined letter of an item triggers it.
- When Option is released, underlines disappear immediately.

### 5.9 Word Wrap (Format → Word Wrap)
- Default: **off**.
- When off: `editorTextView.textContainer?.widthTracksTextView = false`; horizontal scrollbar appears; text lines extend horizontally; long lines are not broken.
- When on: `textContainer?.widthTracksTextView = true`; horizontal scrollbar hides; lines wrap at the editor's right edge.
- The menu item shows a checkmark when on.

### 5.10 Status bar visibility (View → Status Bar)
- Default: **on**.
- When off: the status bar view's height is set to 0 and it is hidden.
- When on: status bar is visible at 22pt.
- The menu item shows a checkmark when on.

### 5.11 Time/Date (Edit → Time/Date, F5)
- Inserts at the cursor position the current local time and date in the format:
  - `"HH:mm M/d/yyyy"` using `DateFormatter` with locale `Locale(identifier: "en_US_POSIX")` and no AM/PM (24-hour). Example: `14:32 5/25/2026`.
- The insertion is a single undo group.

### 5.12 Zoom
- Levels (percent): 10, 15, 20, 25, 33, 50, 67, 75, 80, 90, **100**, 110, 125, 150, 175, 200, 250, 300, 400, 500.
- Default: 100.
- Zoom In moves to the next higher level (caps at 500).
- Zoom Out moves to the next lower level (floors at 10).
- Restore Default Zoom sets to 100.
- Zoom scales the editor's font size proportionally (font size = base size × percent / 100).
- The base size is whatever was last picked via Font dialog (default `Menlo 11pt`).
- The status bar's `100%` segment updates immediately.

### 5.13 Encoding & line endings — detection on open
Implemented in `Files/EncodingDetector.swift` and `Files/LineEndingDetector.swift`.

**Encoding detection order:**
1. If first 3 bytes are `EF BB BF` → UTF-8 with BOM.
2. If first 2 bytes are `FF FE` → UTF-16 LE.
3. If first 2 bytes are `FE FF` → UTF-16 BE.
4. Otherwise → UTF-8 (no BOM). If decoding fails, fall back to `String.Encoding.windowsCP1252` and tag the document as `UTF-8` for status bar (do not invent a new label).

**Line ending detection:**
- Count occurrences of `\r\n`, isolated `\n`, and isolated `\r`.
- Pick the one with the highest count. Ties prefer `CRLF`, then `LF`, then `CR`.
- If no line breaks present, default to `CRLF`.

### 5.14 Encoding & line endings — saving
- Save uses the document's current encoding and EOL setting.
- All `\n` in the in-memory text are converted to the selected EOL byte sequence when writing.
- BOM is prepended only when encoding is `UTF-8 with BOM`, `UTF-16 LE`, or `UTF-16 BE`.

### 5.15 Drag-and-drop
- Each `NotepadWindow` registers for dragged file types (`NSPasteboard.PasteboardType.fileURL`).
- Dropping one file: if current document is untitled & empty, open in place; otherwise open in a new window.
- Dropping multiple files: each opens in a separate new window.
- Only files with extensions `.txt`, `.log`, `.md`, `.csv`, or no extension are accepted. Others rejected with a beep.

### 5.16 File type registration
- `Info.plist` declares `CFBundleDocumentTypes` for `public.plain-text`, `public.text`, with role `Editor`.
- Result: Finder shows "Notepad" in the Open With submenu for `.txt` files. We do not request to be the default.

### 5.17 Help menu
- All three items — `View Help`, `Send Feedback`, `About Notepad` — open the same `AboutDialog`.

---

## 6. Dialog Specifications

All dialogs are custom `NSWindow` subclasses of `DialogWindow` (borderless, modal, draggable by title bar). All have:
- White background (`chromeBackground`).
- 1pt `chromeBorderHeavy` outline.
- Custom title bar identical to the main window's title bar but **only** with a close (✕) button — no min/max.
- OK/Cancel buttons at the bottom-right: 75pt wide × 23pt tall, 8pt padding from edges, 8pt between buttons.
- Buttons drawn as 1pt-bordered rectangles in `chromeBorderHeavy`, `chromeBackground` fill, hover fill `menuHoverBg`.
- Default button (Return key) drawn with a 2pt border in `selectionBg`.

### 6.1 Find dialog (`Dialogs/FindDialog.swift`)
- Size: 360 × 140.
- Title: `Find`.
- Modeless (does not block editor). Stays open across actions. Singleton per app.
- Layout:
  ```
  ┌──────────────────────────────────────────────┐
  │ Find       ✕                                 │
  ├──────────────────────────────────────────────┤
  │ Find what: [____________________] [Find Next]│
  │                                              │
  │ [ ] Match case      Direction:    [ Cancel ] │
  │ [ ] Wrap around       ( ) Up                 │
  │                       (•) Down               │
  └──────────────────────────────────────────────┘
  ```
- State persists for the app's lifetime: search term, both checkboxes, direction radio.
- "Find Next" searches from the current cursor position in the active editor.
- If not found, beep and show inline message `"Cannot find \"<term>\""` below the field for 2 seconds.

### 6.2 Replace dialog (`Dialogs/ReplaceDialog.swift`)
- Size: 360 × 180. Same layout as Find but adds:
  - Second text field `Replace with:`
  - Buttons: `Find Next`, `Replace`, `Replace All`, `Cancel`
- `Replace` replaces the current selection (if it matches the search term) and finds next.
- `Replace All` replaces all occurrences from start; shows alert `"Replaced N occurrences."` after.

### 6.3 Go To Line (`Dialogs/GoToLineDialog.swift`)
- Size: 280 × 110.
- Modal (blocks active editor only).
- Single field `Line number:` followed by OK / Cancel.
- On OK, move cursor to start of that line and scroll into view. If line > total, scroll to last line.

### 6.4 Font dialog (`Dialogs/FontDialog.swift`)
- Size: 480 × 360.
- Title: `Font`.
- Modal.
- Layout matches Win10 Choose Font dialog (left-to-right three columns):
  - **Font**: text field above an NSTableView list of all installed font families (use `NSFontManager.shared.availableFontFamilies`).
  - **Font style**: text field above NSTableView list of styles for selected family (`Regular`, `Italic`, `Bold`, `Bold Italic`).
  - **Size**: text field above NSTableView list of sizes `8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72`.
- Sample box: 280×60pt at bottom-left, displays `"AaBbYyZz"` in selected font at selected size. 1pt `chromeBorderHeavy` border, white bg.
- OK / Cancel bottom right.
- On OK: applies font to **all open** editor views and persists as new default in `UserDefaults` key `editor.font`.

### 6.5 Page Setup (`Dialogs/PageSetupDialog.swift`)
- Size: 480 × 460.
- Modal. Layout:
  - **Paper** group: Size dropdown (Letter, A4, Legal), Source dropdown (Automatic).
  - **Orientation** group: radios `Portrait` (default), `Landscape`.
  - **Margins (millimeters)** group: four fields Left/Right/Top/Bottom, default `19.1` each.
  - **Header**: text field, default `&f`.
  - **Footer**: text field, default `Page &p`.
  - **Preview**: a 120×160pt rect showing a miniature page outline.
- OK saves to `UserDefaults` keys under prefix `pageSetup.`.
- Codes documented inline as static text below the header/footer fields:
  - `&f` filename, `&p` page number, `&d` date, `&t` time, `&&` literal ampersand.

### 6.6 About dialog (`Dialogs/AboutDialog.swift`)
- Size: 360 × 200.
- Modal.
- Content (centered):
  - Line 1: `Notepad` in Fonts.dialogTitle.
  - Line 2: `Version 1.0` in Fonts.dialogLabel.
  - Line 3: `A faithful Windows 10 Notepad recreation for macOS.`
  - Line 4: `© 2026 Bimboware`
- Single button: `OK`, default.

### 6.7 Save Changes prompt (`Dialogs/SaveChangesPrompt.swift`)
- Size: 420 × 130.
- Modal sheet attached to the parent window.
- Message: `"Do you want to save changes to \(displayName)?"`
- Three buttons right-aligned: `Save` (default), `Don't Save`, `Cancel`.

### 6.8 File browser — Open & Save As (`Dialogs/FileBrowser/*`)
- Size: 800 × 520.
- Modal.
- Layout:
  ```
  ┌─────────────────────────────────────────────────────────────────────┐
  │ Open                                                              ✕ │
  ├─────────────────────────────────────────────────────────────────────┤
  │ [< >] [⌃ refresh]  [Path > breadcrumb > here]      [Search______]  │
  ├──────────────┬──────────────────────────────────────────────────────┤
  │ ▼ Quick      │  Name              Date modified   Type     Size    │
  │   Desktop    │  ───────────────────────────────────────────────     │
  │   Downloads  │  📁 Documents       2026-05-20      Folder           │
  │   Documents  │  📄 todo.txt        2026-05-25      Text     2 KB    │
  │ ▼ This Mac   │  …                                                   │
  │   home       │                                                      │
  │   /          │                                                      │
  ├──────────────┴──────────────────────────────────────────────────────┤
  │ File name: [todo.txt________________________]  [Open ▼] [Cancel]    │
  │ Type:      [Text Documents (*.txt) ▼      ]                         │
  └─────────────────────────────────────────────────────────────────────┘
  ```
- Sidebar items (hardcoded): Desktop, Downloads, Documents (under "Quick"); home (`NSHomeDirectory()`), root `/` (under "This Mac").
- File list: real `FileManager` enumeration of the current directory. Two columns minimum: Name, Date modified. Folders sort first.
- Double-click folder → navigate into it. Double-click file → confirm (Open or Save As).
- Breadcrumb shows path components, each clickable.
- Filter dropdown: `Text Documents (*.txt)`, `All Files (*.*)`.
- Save As variant: title `Save As`; below filename field also show **Encoding** dropdown (`UTF-8`, `UTF-8 with BOM`, `UTF-16 LE`, `UTF-16 BE`) and **Line ending** dropdown (`Windows (CRLF)`, `Unix (LF)`, `Macintosh (CR)`). Defaults to the document's current values.
- Search field: filters the file list by case-insensitive substring match on name.

---

## 7. Implementation Plan

> **Phase order is mandatory.** Each phase ends with a DoD checklist. Do not start the next phase until all DoD items pass.

### Phase 0 — Project bootstrap

**Tasks**
1. Create the Xcode project at `Notepad.xcodeproj` with macOS App template, language Swift, framework AppKit, no Core Data, no tests.
2. Set Bundle Identifier `com.bimboware.notepad`, deployment target macOS 13.0, app name `Notepad`.
3. Delete the default `ViewController.swift`, `Main.storyboard`, and `MainMenu.xib`. Set `NSPrincipalClass = NSApplication` and remove `NSMainStoryboardFile` from `Info.plist`.
4. Set `NSApplicationDelegateAdaptor`-equivalent: in `AppDelegate.swift`, mark with `@main`, override `applicationDidFinishLaunching(_:)`.
5. Create the empty folder/file skeleton listed in §3. Each file may contain only `import AppKit` and an empty type declaration matching its filename.
6. Create `Theme/Colors.swift`, `Theme/Fonts.swift`, `Theme/Metrics.swift` with the **exact** code from §4.1, §4.2, §4.3.

**DoD**
- [ ] `xcodebuild -project Notepad.xcodeproj -scheme Notepad build` exits 0.
- [ ] Launching the built app shows an empty (system-default) window or nothing — no crash.
- [ ] All files listed in §3 exist (verify by `find Notepad -name "*.swift" | wc -l` ≥ 30).
- [ ] `Colors`, `Fonts`, `Metrics` enums compile.

---

### Phase 1 — Borderless window with custom title bar

**Tasks**
1. In `NotepadWindow.swift`, subclass `NSWindow`. Use `styleMask: [.borderless, .resizable, .miniaturizable]`, `backingType: .buffered`, `defer: false`.
2. Override `var canBecomeKey: Bool { true }` and `var canBecomeMain: Bool { true }`.
3. In `NotepadWindowController.swift`, create a window of size 900×700 positioned flush top-right of the active screen's `visibleFrame`.
4. Create `TitleBarView.swift` (NSView subclass) sized 32pt tall, full window width. Draw white background and 1pt bottom border using `Colors.chromeBorder`.
5. Implement title text label: left-padded 12pt, vertically centered, `Fonts.chrome`. Initial text: `"Untitled - Notepad"`.
6. Create `TitleBarButton.swift` (NSView subclass). Three instances added right-aligned to the title bar.
7. Implement custom drawing for each glyph as described in §4.4. Implement `mouseEntered`/`mouseExited` for hover state using a tracking area.
8. Wire actions: minimize → `window.miniaturize(nil)`; maximize → `window.toggleFullScreen(nil)`; close → `window.performClose(nil)`.
9. Make the title bar drag the window: override `mouseDown` and `mouseDragged` in `TitleBarView` to call `window?.performDrag(with: event)`.
10. In `AppDelegate.applicationDidFinishLaunching`, instantiate one `NotepadWindowController`, show its window, and make it key.

**DoD**
- [ ] App launches showing a borderless white window in the top-right corner of the screen, 900×700.
- [ ] Title bar shows "Untitled - Notepad" on the left.
- [ ] Three buttons drawn in the top-right corner — minimize, maximize, close — each 46×32pt.
- [ ] Hovering minimize/maximize highlights gray (#E5E5E5); hovering close highlights red (#E81123) with white X.
- [ ] Clicking minimize miniaturizes the window to the Dock.
- [ ] Clicking maximize toggles macOS full screen.
- [ ] Clicking close terminates the app (since it's the only window).
- [ ] Dragging the title bar moves the window.
- [ ] The window has a thin 1pt gray border across the bottom of the title bar.

---

### Phase 2 — In-window menu bar (visual only)

**Tasks**
1. Create `InWindowMenuBarView.swift` (NSView): 22pt tall, full width, placed directly below the title bar. Bottom border 1pt `chromeBorder`.
2. Create `InWindowMenuItemView.swift`: one per menu (`File`, `Edit`, `Format`, `View`, `Help`). Each draws its label, padded 8pt left/right.
3. Implement hover (`menuHoverBg`) and click (`menuActiveBg`) backgrounds via tracking areas.
4. On click, create an empty `NSMenu` and call `popUp(positioning:at:in:)` at the menu item's bottom-left corner.
5. Each `NSMenu` should contain one placeholder item `(coming soon)` disabled.
6. Stub `AltKeyMonitor` (don't wire underlines yet — just create the file).

**DoD**
- [ ] Below the title bar, a 22pt-tall white menu bar shows `File`, `Edit`, `Format`, `View`, `Help` in that order, each 8pt-padded.
- [ ] Hovering an item highlights it light-blue (#E5F3FF).
- [ ] Clicking an item shows a dropdown with one disabled "coming soon" item.
- [ ] The menu bar has a 1pt gray border at the bottom.

---

### Phase 3 — Editor area and status bar shell

**Tasks**
1. Create `EditorScrollView.swift` (NSScrollView) and `EditorView.swift` (NSTextView). Place the scroll view filling the area between the menu bar and the status bar.
2. Configure the text view: `isRichText = false`, `allowsUndo = true`, default font `Fonts.editorDefault`, text color `Colors.editorText`, background `Colors.editorBg`, `insertionPointColor = .black`, `selectedTextAttributes = [.backgroundColor: Colors.selectionBg, .foregroundColor: Colors.selectionText]`.
3. Set `textContainerInset = NSSize(width: 4, height: 4)`.
4. Default: Word Wrap **off** — set `textContainer?.widthTracksTextView = false`, `textContainer?.containerSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)`, `isHorizontallyResizable = true`.
5. Create `StatusBarView.swift`: 22pt tall, full width, `Colors.statusBarBg`, top border 1pt `chromeBorder`.
6. Add four labels:
   - Left: `Ln 1, Col 1` (will be wired in Phase 5).
   - Right (right-to-left): `UTF-8`, `Windows (CRLF)`, `100%` — each in a `StatusBarSegment.swift` (NSView with text + click handling). 1pt `statusBarSeparator` between segments.
7. Phase 3 segments are not yet clickable; they show the static defaults.

**DoD**
- [ ] Typing into the window produces text in the editor area.
- [ ] Text is rendered in Menlo 11pt black on white.
- [ ] Selecting text shows blue (#0078D7) background with white text.
- [ ] Status bar is visible at the bottom: 22pt tall, light gray.
- [ ] Status bar left shows `Ln 1, Col 1` (static for now).
- [ ] Status bar right shows `100% | Windows (CRLF) | UTF-8` with separators.
- [ ] Scrollbars appear (default Mac for now — they will be replaced in Phase 4).
- [ ] Typing many lines causes the editor to scroll.

---

### Phase 4 — Custom Win10 scrollbars

**Tasks**
1. Implement `WinScroller.swift` per §4.7. Override `drawKnobSlot(in:highlight:)`, `drawKnob()`, `rect(for:)`.
2. Override `class var isCompatibleWithOverlayScrollers: Bool { false }`.
3. Custom-draw the up/down arrow buttons in `drawArrow(_:highlight:)`. Implement hit-testing for those areas in `hitPart` / `testPart`.
4. Install on the editor scroll view: `scrollView.verticalScroller = WinScroller()`, set `scrollerStyle = .legacy`, `hasVerticalScroller = true`, `hasHorizontalScroller = true` (the horizontal will be visible/hidden by Word Wrap toggle later).
5. Implement repeating scroll when arrow held: timer-based, 300ms initial, 50ms repeat.

**DoD**
- [ ] Scrollbars are always visible (do not auto-hide).
- [ ] Vertical scrollbar is 17pt wide.
- [ ] At top and bottom of the vertical scrollbar there are square arrow buttons with triangle glyphs.
- [ ] Track is light gray; thumb is gray; thumb darkens on hover.
- [ ] Clicking an arrow scrolls one line; holding it scrolls continuously.
- [ ] Horizontal scrollbar present (until word wrap is on).

---

### Phase 5 — Edit menu actions, line/column tracker

**Tasks**
1. Replace File/Edit/Format/View/Help dropdowns with real items per §5.7. Wire selectors on the responder chain.
2. Edit menu items in order with `NSMenuItem.separatorItem()` separators:
   - Undo (⌘Z), Redo (⌘Y), —, Cut (⌘X), Copy (⌘C), Paste (⌘V), Delete (Delete), —, Find (⌘F), Find Next (F3), Find Previous (Shift+F3), Replace (⌘H), Go To (⌘G), —, Select All (⌘A), Time/Date (F5).
3. Time/Date inserts current time/date per §5.11. The other menu items map to standard NSResponder selectors (`undo:`, `redo:`, `cut:`, `copy:`, `paste:`, `delete:`, `selectAll:`).
4. Find/Replace/Go To items show alerts `"Coming in Phase 11–13"` for now.
5. Create `LineColumnTracker.swift`. Subscribe to `NSTextView.didChangeSelectionNotification`. On change, compute line and column (1-indexed) from the insertion point; call back into `StatusBarView` to update the `Ln/Col` label.
6. Mark document dirty on every text change (`NSText.didChangeNotification`).

**DoD**
- [ ] Edit menu contains all items in §5.7 with the listed keyboard shortcuts.
- [ ] Typing text and pressing ⌘Z undoes; ⌘Y redoes.
- [ ] Cut, Copy, Paste, Select All work.
- [ ] F5 inserts current time/date in format `HH:mm M/d/yyyy`.
- [ ] As cursor moves, `Ln X, Col Y` updates in the status bar (1-indexed).
- [ ] Typing causes the title bar text to update to include ` — Modified`.

---

### Phase 6 — File menu with native dialogs (temporary)

**Tasks**
1. File menu items in order:
   - New (⌘N), New Window (no shortcut — same as New for now), —, Open (⌘O), Save (⌘S), Save As (⌘⇧S), —, Page Setup (no shortcut), Print (⌘P), —, Exit (⌘Q).
2. Implement `DocumentController.swift` as a singleton that owns an array of `NotepadWindowController`. Provides `newWindow()`, `openFile(at:)`, `closeWindow(_:)`.
3. New → spawn a new window via `DocumentController.newWindow()`.
4. Open → present `NSOpenPanel` (temporarily; replaced in Phase 19). On confirm, call `openFile(at:)` which creates a new window and loads the file using `DocumentReader`.
5. Implement `DocumentReader.swift` and `DocumentWriter.swift` using the encoding detection rules in §5.13 and writing per §5.14.
6. Save → if document has URL, write to it. Else fall through to Save As.
7. Save As → present `NSSavePanel` (temporarily). On confirm, set the URL on `DocumentState`, write, and update title.
8. Page Setup, Print → temporarily show an alert `"Coming in Phase 15–16"`.
9. Exit → `NSApplication.shared.terminate(nil)`. The terminate handler checks all dirty windows and prompts (Phase 23 will refine).
10. Closing the last window quits the app via `applicationShouldTerminateAfterLastWindowClosed`.

**DoD**
- [ ] File menu shows all items in the listed order.
- [ ] ⌘N opens a new window; multiple windows can coexist.
- [ ] ⌘O opens the native file picker; selecting a `.txt` file loads its content into a new window.
- [ ] After loading a file, the title bar shows the absolute path followed by ` - Notepad`.
- [ ] Status bar EOL and Encoding segments reflect detected values for the opened file.
- [ ] ⌘S on an untitled document opens Save As; ⌘S on a saved document overwrites.
- [ ] After Save, the title bar's ` — Modified` suffix disappears.
- [ ] Closing the last window quits the app.

---

### Phase 7 — macOS top menu bar mirror

**Tasks**
1. Create `MenuBuilder.swift`. Build an `NSMenu` for the macOS top bar with submenus matching the in-window menus: App (with `About Notepad`, `Quit`), File, Edit, Format, View, Help.
2. Each item points to the same selector as the corresponding in-window menu item.
3. Set `NSApp.mainMenu = MenuBuilder.build()` in `applicationDidFinishLaunching`.

**DoD**
- [ ] macOS top menu bar shows: Notepad | File | Edit | Format | View | Help.
- [ ] Each top-bar item, when chosen, triggers the same behavior as the in-window menu equivalent.
- [ ] Selecting About Notepad from the top bar opens the About alert (or temporary placeholder until Phase 14).

---

### Phase 8 — Format menu (Word Wrap + native font dialog)

**Tasks**
1. Format menu items: `Word Wrap`, `Font…`.
2. Word Wrap: toggles per §5.9. Sync checkmark state on the menu item.
3. Font: temporarily open `NSFontPanel.shared`. Apply selected font to the active editor. Phase 18 will replace this with custom dialog.

**DoD**
- [ ] Format → Word Wrap toggles wrapping; checkmark appears when on.
- [ ] When Word Wrap is on, no horizontal scrollbar; long lines wrap.
- [ ] When Word Wrap is off, long lines extend right and horizontal scrollbar appears.
- [ ] Format → Font opens NSFontPanel; choosing a font applies it.

---

### Phase 9 — View menu (Zoom + Status Bar toggle)

**Tasks**
1. View menu items: `Zoom` submenu (`Zoom In`, `Zoom Out`, `Restore Default Zoom`), —, `Status Bar` (toggle).
2. Implement `ZoomController.swift` per §5.12. Maintain current zoom level on each `DocumentState`.
3. Status Bar toggle: hide or show the `StatusBarView`. Sync checkmark.

**DoD**
- [ ] ⌘+ increases zoom one step; status bar updates.
- [ ] ⌘- decreases zoom; ⌘0 returns to 100%.
- [ ] Font in the editor visibly scales.
- [ ] Zoom respects the 20-level table; does not go above 500% or below 10%.
- [ ] View → Status Bar hides the status bar; the editor grows to fill.

---

### Phase 10 — Status bar interactivity (live convert)

**Tasks**
1. Make each right-side status bar segment clickable per §4.6.
2. Clicking the zoom segment shows a popup menu with three items (`Zoom In`, `Zoom Out`, `Restore Default Zoom`) — same actions as the menu.
3. Clicking the line ending segment shows `Windows (CRLF)`, `Unix (LF)`, `Macintosh (CR)`. Selecting one changes `DocumentState.eol`, re-tags status bar text, marks dirty.
4. Clicking the encoding segment shows `UTF-8`, `UTF-8 with BOM`, `UTF-16 LE`, `UTF-16 BE`. Same flow.

**DoD**
- [ ] Clicking `100%` opens a 3-item popup positioned above the segment.
- [ ] Clicking `Windows (CRLF)` opens a 3-item EOL popup; selecting `Unix (LF)` updates the segment to read `Unix (LF)` and marks document dirty.
- [ ] Same for encoding segment.
- [ ] Saving after a conversion writes the file with the new EOL/encoding bytes (verify by `xxd file.txt | head` and seeing the expected line-ending bytes / BOM).

---

### Phase 11 — Custom Find dialog

**Tasks**
1. Implement `DialogWindow.swift` base class (borderless modal-or-modeless NSWindow with custom chrome).
2. Implement `FindDialog.swift` per §6.1.
3. Wire ⌘F / F3 / Shift+F3 to open + repeat.
4. Implement substring search (with optional case sensitivity, wrap-around). Direction radio reverses the search.

**DoD**
- [ ] ⌘F opens the Find dialog at 360×140 with the custom Win-style chrome.
- [ ] Find Next jumps to the next match from the cursor.
- [ ] Wrap Around when checked continues from start after the end is reached.
- [ ] Direction Up searches backward.
- [ ] Match Case is honored.
- [ ] F3 repeats Find Next without reopening the dialog.
- [ ] Dialog stays open across actions; state persists.

---

### Phase 12 — Custom Replace dialog

**Tasks**
1. Implement `ReplaceDialog.swift` per §6.2. Shares search logic with Find dialog.
2. Wire ⌘H.
3. Replace All shows `"Replaced N occurrences."` confirmation alert.

**DoD**
- [ ] ⌘H opens Replace dialog (360×180).
- [ ] Find Next, Replace, Replace All all work.
- [ ] Replace All shows the count alert.

---

### Phase 13 — Go To Line dialog

**Tasks**
1. Implement `GoToLineDialog.swift` per §6.3.
2. Wire ⌘G.

**DoD**
- [ ] ⌘G opens Go To Line (280×110), modal.
- [ ] Entering a valid line number jumps cursor to that line.
- [ ] Out-of-range numbers clamp to last line.

---

### Phase 14 — About dialog

**Tasks**
1. Implement `AboutDialog.swift` per §6.6.
2. Wire all three Help menu items to open this dialog.
3. Wire the macOS top bar's `About Notepad` to open this dialog (replace the placeholder from Phase 7).

**DoD**
- [ ] Help → View Help opens About dialog.
- [ ] Help → Send Feedback opens the same About dialog.
- [ ] Help → About Notepad opens the same About dialog.
- [ ] The dialog contains the exact 4 lines listed in §6.6.

---

### Phase 15 — Page Setup dialog

**Tasks**
1. Implement `PageSetupDialog.swift` per §6.5.
2. Persist values to `UserDefaults`.

**DoD**
- [ ] File → Page Setup opens the custom dialog at 480×460.
- [ ] All controls present per §6.5.
- [ ] OK persists values (reopen and verify).
- [ ] Header/footer code legend visible below the fields.

---

### Phase 16 — Print

**Tasks**
1. File → Print runs `NSPrintOperation.printOperation(with:)` on the editor view. Apply the Page Setup values from `UserDefaults` (paper size, margins, orientation) via the `NSPrintInfo` instance.
2. The standard macOS print sheet appears.

**DoD**
- [ ] ⌘P opens the standard macOS print sheet.
- [ ] Selected paper size and margins from Page Setup are reflected in the preview.
- [ ] Printing produces a multi-page PDF (use "Save as PDF" from the print sheet) that contains the document text.

---

### Phase 17 — Alt key accelerators

**Tasks**
1. Implement `AltKeyMonitor.swift` using `NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)`. Publish `isAltDown: Bool` via a notification or closure.
2. `InWindowMenuItemView` listens; when `isAltDown` becomes true, redraws its label with the accelerator letter underlined.
3. `KeyboardShortcuts.swift` installs a key-down monitor: when Option+letter pressed and matches `F/E/O/V/H`, programmatically opens that menu's dropdown.
4. Inside an open `NSMenu`, the accelerator key handling is provided by AppKit if items use `&` syntax (e.g., `&New`). Set item titles with the `&` prefix; convert in `MenuBuilder` to NSMenuItem's `keyEquivalent` where appropriate.

**DoD**
- [ ] Holding Option underlines F, E, o, V, H in the in-window menu bar.
- [ ] Releasing Option removes underlines immediately.
- [ ] Option+F opens File menu; Option+E opens Edit; etc.
- [ ] Inside an open menu, pressing the underlined letter of an item triggers it.

---

### Phase 18 — Custom Font dialog

**Tasks**
1. Implement `FontDialog.swift` per §6.4.
2. Replace the temporary `NSFontPanel` call from Phase 8 with this dialog.
3. Persist chosen font to `UserDefaults` key `editor.font` (serialize via `NSKeyedArchiver` of `NSFont`).

**DoD**
- [ ] Format → Font opens custom 480×360 dialog with three columns + sample box.
- [ ] Sample box updates as selection changes.
- [ ] OK applies font to all open editors and persists; reopening the app uses the chosen font as default.

---

### Phase 19 — Custom file browser dialog

**Tasks**
1. Implement `FileBrowser/*` per §6.8.
2. Replace `NSOpenPanel` (Phase 6) with `FileBrowserDialog.open(filter:)` and `NSSavePanel` with `FileBrowserDialog.saveAs(suggestedName:encoding:eol:)`.
3. The Save As variant returns the chosen URL, encoding, and EOL to the caller.

**DoD**
- [ ] File → Open shows the custom browser at 800×520 with sidebar, file list, breadcrumb, filter, search.
- [ ] Navigating folders works (double-click).
- [ ] Sidebar entries jump to those paths.
- [ ] Breadcrumb is clickable.
- [ ] Filter switches between `*.txt` and `*.*`.
- [ ] Search filters list live.
- [ ] File → Save As shows the same dialog plus encoding + EOL dropdowns at the bottom.
- [ ] Saving writes the file with the chosen encoding/EOL (verify bytes).
- [ ] No `NSOpenPanel` or `NSSavePanel` is invoked anywhere in the final code (grep for `NSOpenPanel` and `NSSavePanel` should return 0 results in `Notepad/`).

---

### Phase 20 — Drag-and-drop

**Tasks**
1. In `NotepadWindow`, register for `NSPasteboard.PasteboardType.fileURL`.
2. Implement `draggingEntered`, `prepareForDragOperation`, `performDragOperation` per §5.15.
3. Reject non-text files (extensions not in `[txt, log, md, csv, ""]`) with `NSSound.beep()` and return false.

**DoD**
- [ ] Dragging a `.txt` file from Finder onto an empty Untitled window opens it in that window.
- [ ] Dragging a `.txt` onto a window with content opens it in a new window.
- [ ] Dragging multiple `.txt` files opens each in a new window.
- [ ] Dragging a `.png` file beeps and is rejected.

---

### Phase 21 — File-type registration

**Tasks**
1. Edit `Info.plist` to add `CFBundleDocumentTypes` declaring `public.plain-text` and `public.text` with role `Editor`, name `Plain Text`.
2. Implement `applicationOpenURLs(_:_:)` (or `application(_:open:)`) to open the file in a new window (untitled-empty replacement behavior).

**DoD**
- [ ] After build & install (drag .app to /Applications), right-clicking a `.txt` file in Finder shows Notepad in Open With.
- [ ] Opening a `.txt` via Open With launches the app and shows the file.
- [ ] Double-clicking a `.txt` while the app is running (after setting it as default) opens it in a new window.

---

### Phase 22 — Window position memory

**Tasks**
1. On window close, save `window.frame` to `UserDefaults` key `lastFrame.0`.
2. On app launch, restore from `lastFrame.0` if present; otherwise use the top-right default.
3. New windows opened from File → New use a cascading offset (`+22, -22`) from the last opened window.

**DoD**
- [ ] Move and resize the window; close the app; relaunch — window appears at the same frame.
- [ ] Delete `UserDefaults` (`defaults delete com.bimboware.notepad`) and relaunch — window appears at top-right 900×700.
- [ ] File → New from a positioned window opens a new window offset 22pt right and 22pt down.

---

### Phase 23 — Save-on-close prompt (custom dialog)

**Tasks**
1. Implement `SaveChangesPrompt.swift` per §6.7 as a window-modal sheet.
2. Hook into `NotepadWindow.windowShouldClose(_:)` and `NSApp.applicationShouldTerminate(_:)`. If any window is dirty, show the prompt instead of closing/quitting.
3. Wire the three buttons per §5.5.

**DoD**
- [ ] Closing a dirty window shows the custom Win-style prompt with text `Do you want to save changes to <displayName>?`.
- [ ] Save → writes the file (or opens Save As if untitled) then closes.
- [ ] Don't Save → closes immediately, no write.
- [ ] Cancel → returns to editor, window stays open.
- [ ] Closing a clean window does not show the prompt.
- [ ] ⌘Q with a dirty window shows the prompt for each dirty window in turn.

---

### Phase 24 — Final polish & acceptance

**Tasks**
1. Walk through every menu item in every menu and verify it triggers the documented behavior.
2. Walk through every keyboard shortcut from §5.7 with both ⌘ and Ctrl modifiers.
3. Verify the visual checklist in §8.
4. Run the full acceptance script in §8.

**DoD**
- [ ] All items in §8 Acceptance pass.

---

## 8. Acceptance Tests

> Run these in order on a freshly built `.app`. Each must pass for the project to be considered complete.

### 8.1 Visual checklist
- [ ] Window opens flush to top-right of screen at 900×700 on first launch.
- [ ] Title bar matches §4.4 layout, fonts, colors, and button hover behavior.
- [ ] Menu bar matches §4.5 layout, hover/active highlight, and dropdown behavior.
- [ ] Status bar matches §4.6 (Ln/Col left; zoom / EOL / encoding right with separators).
- [ ] Editor uses Menlo 11pt black on white; selection is `#0078D7` with white text.
- [ ] Scrollbars are always visible, 17pt thick, with up/down arrow buttons.
- [ ] No traffic lights (red/yellow/green) anywhere; no macOS title bar.

### 8.2 Behavior script
1. Launch app → empty Untitled window appears top-right.
2. Type `Hello, world.` → title bar updates to `Untitled — Modified - Notepad`.
3. Press ⌘S → custom Save As dialog opens; navigate to ~/Desktop, name `test.txt`, default encoding UTF-8 / EOL Windows (CRLF), Save.
4. Title bar now reads `/Users/<you>/Desktop/test.txt - Notepad`.
5. Run `xxd ~/Desktop/test.txt | head -1` in Terminal → bytes show `Hello, world.\r\n` (no BOM).
6. Status bar click `Windows (CRLF)` → popup; choose `Unix (LF)` → segment updates, title gains ` — Modified`.
7. ⌘S → file overwrites; `xxd` now shows `\n` (no `\r`).
8. Click status bar `UTF-8` → choose `UTF-8 with BOM`; save; `xxd` shows leading `EF BB BF`.
9. ⌘N → new window opens (offset from current).
10. ⌘O → custom file browser opens; navigate sidebar to Desktop, pick `test.txt` → opens in new window with detected `Unix (LF)` and `UTF-8 with BOM`.
11. ⌘F → Find dialog (custom). Find `world`. ⌘W if available, else close dialog.
12. ⌘H → Replace `world` with `macOS`. Replace All → alert "Replaced 1 occurrences." Save.
13. ⌘G → Go To Line 1 → cursor moves to start.
14. F5 → time/date inserted at cursor (`HH:mm M/d/yyyy`).
15. Format → Word Wrap → wrapping toggles; horizontal scrollbar disappears.
16. Format → Font → custom dialog opens; pick `Courier New`, `Bold`, `14`; OK → editor text restyles.
17. View → Zoom → Zoom In a few times; status bar shows higher percent; ⌘0 → back to 100%.
18. View → Status Bar → status bar hides; toggle again → reappears.
19. Hold Option → menu accelerators (F, E, o, V, H) become underlined; Option+F opens File menu.
20. Drag a `.txt` from Finder onto a window with content → opens in a new window.
21. Drag a `.png` onto a window → beep, no open.
22. File → Page Setup → custom dialog (480×460) with all controls per §6.5; change margin, OK; reopen → value persisted.
23. File → Print → standard macOS print sheet appears; preview shows the document text.
24. Close a dirty window → custom Save Changes prompt. Click Cancel → returns. Click Don't Save → window closes.
25. ⌘Q with one clean window → app quits.
26. Relaunch → window appears at the position/size of the last-closed window.
27. Delete defaults (`defaults delete com.bimboware.notepad`), relaunch → window at top-right 900×700.
28. Help → View Help / Send Feedback / About Notepad → all three open the same About dialog with the 4 lines from §6.6.

### 8.3 Code checklist
- [ ] `grep -r NSOpenPanel Notepad/` returns 0 lines.
- [ ] `grep -r NSSavePanel Notepad/` returns 0 lines.
- [ ] `grep -r NSFontPanel Notepad/` returns 0 lines.
- [ ] `grep -r NSAlert Notepad/Dialogs/` returns 0 lines (no NSAlert use in our dialogs — all custom).
- [ ] No SwiftUI imports (`grep -r "import SwiftUI" Notepad/` returns 0).
- [ ] No third-party packages declared.
- [ ] `xcodebuild -project Notepad.xcodeproj -scheme Notepad -configuration Release build` exits 0 with 0 warnings other than deprecation notices from AppKit.

---

## 9. Glossary & references

- **Chrome**: any UI outside the text editing area — title bar, menu bar, status bar, dialog frames.
- **Dirty**: the in-memory text differs from the last-saved version (or has never been saved and is non-empty).
- **EOL**: end-of-line byte sequence — `\r\n` (CRLF, Windows), `\n` (LF, Unix), `\r` (CR, classic Mac).
- **DoD**: Definition of Done — the checklist that gates phase completion.
- **Accelerator**: the Alt+letter shortcut that opens a menu (e.g., Alt+F opens File).

End of PRD.
