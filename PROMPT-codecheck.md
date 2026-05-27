# Ralph codecheck iteration prompt

You are running **one iteration** of an autonomous code-quality sweep over
the Notepad project. The wrapper script (`ralph-codecheck.sh`) re-invokes
you fresh each time with no prior session. Do not try to do more than one
defect per iteration. Do not ask the user questions — make the reasonable
call and proceed.

Your job is **not** to add features. Your job is to find one concrete
defect — a place where the existing code is unstable, incomplete,
crash-prone, or wired up wrong — and fix it so the app gets closer to
"actually works end-to-end". The goal is a usable Notepad clone: the user
must be able to launch, type, use menus, open files, save files, and
quit without crashes or no-ops.

The reference project skill is `.claude/skills/codecheck/SKILL.md` —
read it. It defines the defect categories you should be hunting and the
order in which to triage them.

---

## Inputs you can rely on

- **PRD**: `PRD.md` — authoritative spec for behavior.
- **Reference image**: `notepad.png` — the visual target.
- **Build command**: `./build-project.sh` (wraps `xcodegen` + `xcodebuild`).
- **Smoke test**: `./quality-check.sh -b` — builds, launches, asks
  WindowServer how many windows the app has, scans stderr for crashes,
  exits 0 on full pass. **Treat exit 0 as the only proof the app works.**
- **Defect skill**: `.claude/skills/codecheck/SKILL.md`.

---

## Step 1 — Verify the current state is sane

Run:

```
./quality-check.sh -b
```

Capture the exit code as `QC_RC`. Read `.quality-check/report.md` and
`.quality-check/stderr.log`.

- If `QC_RC == 0` **and** the report shows ≥1 on-screen window **and**
  stderr is empty: the app builds and runs. Proceed to Step 2 to look for
  defects.
- If `QC_RC != 0`: the app is broken in a way the QA harness already
  caught (no window, crash, etc.). Your defect is whatever the report
  points to. Go straight to Step 3 with that as your target. **Skip Step 2.**

---

## Step 2 — Pick the next defect

Walk the **codecheck skill's defect ladder** top-to-bottom. Stop at the
first category that has a real hit in this codebase. For each candidate
you find, verify it is real (read the actual code; don't pattern-match on
filenames). Pick ONE defect to fix this iteration.

If you walk the whole ladder and find nothing real, write:

```
echo empty > .ralph-status
```

Print `[codecheck] iter result: empty` and stop. Do nothing else.

Examples of valid defects (non-exhaustive — see the skill for the full list):

- A menu item exists in `MenuBuilder.swift` but its action is `nil`, a
  no-op `_ = sender`, or routed to a method that doesn't exist.
- An `IBAction`/`@objc func` is declared but its body is empty or just a
  TODO comment.
- A force-unwrap (`!`) on a value that can plausibly be `nil` (`window!`
  during init, `NSScreen.main!` with no fallback).
- A keyboard shortcut is installed but its target controller is `nil` at
  the moment the shortcut fires.
- A notification observer is registered but never fires (no one posts
  it), or a notification is posted but never observed.
- `applicationShouldTerminateAfterLastWindowClosed` returns wrong value
  vs. PRD.
- An `NSResponder` first-responder method is missing so menu commands
  appear enabled but do nothing (cut/copy/paste/undo/redo etc.).
- `NSTextView.isEditable` is false so the user can't type.
- A view is added to a window but its frame is `.zero` so it's invisible.
- A file the build target needs but `Project.yml` doesn't include.

**Do not** treat warnings or style nits as defects in this loop. Stick to
things that break runtime behavior.

---

## Step 3 — Fix it (one defect, one commit)

Let `DEFECT` be a kebab-case slug describing the fix
(e.g. `editor-not-editable`, `open-file-menu-action-missing`).

1. Run `git status` — refuse to start if the tree is dirty (the previous
   iteration may have crashed mid-edit). Write `failed:dirty-tree` to
   `.ralph-status` and stop.
2. Make the minimum code change that fixes the defect. Edit only what
   is required. Do **not** rename, restructure, or refactor adjacent
   code "while you're there".
3. **Files you must never modify**:
   `PRD.md`, `PROMPT.md`, `PROMPT-parallel.md`, `PROMPT-codecheck.md`,
   `ralph.sh`, `ralph-openrouter.sh`, `ralph-parallel.sh`,
   `ralph-codecheck.sh`, `ralph-format.sh`, `quality-check.sh`,
   `build-project.sh`, `.gitignore`, `notepad.png`,
   `.claude/skills/**`.
4. Run `./build-project.sh`. If it fails, your fix is wrong — **revert
   your changes** (`git checkout -- .`), write
   `failed:build:<DEFECT>` to `.ralph-status`, and stop.
5. Run `./quality-check.sh`. If it fails (exit ≠ 0), your fix made the
   runtime worse — **revert your changes** (`git checkout -- .`),
   write `failed:qa:<DEFECT>` to `.ralph-status`, and stop.

---

## Step 4 — Commit & push

1. Stage:
   ```
   git add -A
   ```
2. Refuse to proceed if any of these are staged:
   ```
   git diff --cached --name-only | grep -E '\.(env|key|pem)$|secrets|credentials' && exit 1 || true
   ```
3. Commit:
   ```
   git commit -m "codecheck: <DEFECT> — <one-line summary>

   <2–3 line WHY: what was broken, what symptom this fixes (cross-reference
   ./quality-check.sh exit code or stderr if it caught it).>
   "
   ```
4. Push to main:
   ```
   git push origin main
   ```
   If push fails (non-fast-forward etc.), do NOT force-push. Revert
   (`git reset --hard origin/main`), write
   `failed:push:<DEFECT>` to `.ralph-status`, and stop.
5. Write `fixed:<DEFECT>` to `.ralph-status`.
6. Print `[codecheck] iter result: fixed:<DEFECT>` and stop.

---

## Hard rules

- **One iteration = one defect.** Never chain fixes.
- **Build green before commit, every time.** No exceptions.
- **`./quality-check.sh` exit 0 before commit, every time.** No
  exceptions.
- **Never** push to a branch other than `main` from this loop.
- **Never** modify the loop infrastructure files (see Step 3 list).
- **Never** ask the user a question.
- The `.ralph-status` file is mandatory. Write it before exiting in
  **every** code path. Valid values:
  - `empty` — no defects found, loop should stop
  - `fixed:<slug>` — one defect fixed and pushed
  - `failed:<reason>:<slug>` — could not fix; details in commit / log
