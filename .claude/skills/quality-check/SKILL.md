---
name: quality-check
description: Run the project's smoke-test harness (./quality-check.sh) to verify a freshly-built Notepad.app actually launches, shows a window, and is crash-free. Use this whenever you need to confirm the app is in a working state — after a build, before HITL handoff, or when investigating a "the app doesn't open" report.
---

# Quality check

The `quality-check.sh` script is the **authoritative** way to verify the macOS
app is usable. It launches the built `.app`, asks the WindowServer how many
on-screen windows the process owns, captures a screenshot, scans stderr +
the unified log for crashes, then cleanly terminates the process. It does
**not** require any human interaction.

## When to use

- Right after `./build-project.sh` succeeds, to confirm the binary actually
  runs (a green build does not imply a working app).
- Before writing `review:<N>` in a HITL handoff — attach `.quality-check/report.md`
  and `.quality-check/screenshot.png` to the PR comment so the human reviewer
  has evidence.
- When a user reports "the app doesn't show a window" or similar runtime
  issues — the script's exit code and report distinguish *crash* from
  *running but invisible* from *runs fine*.
- As the final step of any Ralph iteration that touches windowing, menu,
  document, or app-delegate code.

## How to use

```bash
./quality-check.sh            # check existing build
./quality-check.sh -b         # build first, then check
./quality-check.sh -c Release # check Release config (default Debug)
./quality-check.sh -w 5       # wait 5s after launch before measuring (default 3)
./quality-check.sh -k         # leave the app running afterwards
```

## Interpreting the result

| Exit | Meaning                                         | Action |
|-----:|-------------------------------------------------|--------|
| 0    | Process running, ≥1 visible window, no crashes  | Ship it (or hand off for HITL visual review). |
| 1    | Build / launch infrastructure broke             | Read `.quality-check/stderr.log`, fix the script invocation. |
| 2    | App launched but rendered **zero** windows      | **Real bug.** Check `AppDelegate.applicationDidFinishLaunching`, `DocumentController.newWindow()`, and `NotepadWindowController.showWindow`. Look for early `return`s, `nil` window outlets, sheets attached to non-existent parent windows, or `LSUIElement=true` in Info.plist. |
| 3    | App crashed (NSException, EXC_BAD, signal, etc.)| Read `.quality-check/stderr.log` — the trace is there. Fix and re-run. |
| 4    | App exited before measurement                   | Same as 3 but the crash happened before stderr was flushed; check `.quality-check/stdout.log` too. |

## Artifacts

All written under `.quality-check/`:

- `report.md` — human-readable summary (window count, error counts, paths).
- `screenshot.png` — full-screen capture taken `WAIT_SECS` after launch.
- `stderr.log`, `stdout.log` — raw output of the launched process.

When reporting findings in a PR/issue comment, link **report.md** plus the
**screenshot**. Do not paste raw log dumps — point to the file.

## Hard rules

- **Never** modify `quality-check.sh` to make a failing check pass. Fix the
  underlying app code instead.
- **Never** treat a passing build (`./build-project.sh` exit 0) as proof
  the app works. Always run `./quality-check.sh` for runtime evidence.
- **Never** delete `.quality-check/` artifacts before reading them — they
  are the only evidence you have of what the app did this run.
