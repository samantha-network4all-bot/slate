# Ralph iteration prompt

You are running **one iteration** of an autonomous loop. The wrapper script (`ralph.sh`) re-invokes you fresh each time with no prior session. Do not try to do more than one issue per iteration. Do not ask the user questions — make the reasonable call and proceed.

Your final action every iteration **must** be writing one line to `.ralph-status`:

- `empty` — no eligible issue exists; the loop will stop.
- `closed:<N>` — you successfully implemented and closed issue `#N`.
- `failed:<N>` — you tried issue `#N` but build/tests/push failed; you commented on it and left it open.

---

## Context

- **Working directory**: `/Users/arjen/Documents/bimboware/notepad/` (you are already there).
- **GitHub repo**: `samantha-network4all-bot/slate`.
- **Auth**: `gh` and `git` are already authenticated. Do not run `gh auth login` or modify auth.
- **Specification**: `PRD.md` in this directory is the executor playbook with exact colors, fonts, metrics, file paths, dialog dimensions, and a 25-phase build plan. Treat its values as **verbatim**. Do not improvise.
- **Reference image**: `notepad.png` shows the visual target.
- **Build command**: `xcodebuild -project Notepad.xcodeproj -scheme Notepad build` (the Xcode project does not exist on the first iteration — issue `S1` creates it).
- **Test command** (only when the chosen issue's acceptance criteria mention tests): `xcodebuild -project Notepad.xcodeproj -scheme Notepad test`.

---

## Step 1 — Select the next eligible issue

Run:

```
gh issue list --repo samantha-network4all-bot/slate \
  --label needs-triage --state open \
  --json number,title,body --limit 100
```

Sort the results ascending by `number`. Iterate over them and **skip** any candidate where:

1. `number == 1` (the parent PRD is not an executable slice).
2. `title` contains `HITL` or `(HITL` (auto-skip — needs human visual review).
3. The body's `## Blocked by` section lists any `#N` reference whose state is **not** `closed`. Verify each blocker with:
   ```
   gh issue view <N> --repo samantha-network4all-bot/slate --json state
   ```
   Skip the candidate if any blocker is still `OPEN`.

Pick the **first** candidate that survives all three filters.

If none survives:

```
echo empty > .ralph-status
```

Print `[ralph] iter result: empty` and stop. Do nothing else.

---

## Step 2 — Implement the chosen issue

Let `N` be the chosen issue number.

1. Run `git status` and `git diff --stat` to check for uncommitted work left behind by a previous timed-out iteration. If files already exist that match this issue's scope, treat them as in-progress work to **continue and complete**, not as garbage to overwrite. Re-creating identical files wastes the budget you have for this iteration.
2. Read `PRD.md` in full. It is the authoritative spec.
3. Read the issue body in full:
   ```
   gh issue view <N> --repo samantha-network4all-bot/slate --json title,body
   ```
4. Make code edits under `Notepad/` (the source root described in `PRD.md` §3) to satisfy **every** unchecked `- [ ]` item under the issue's "Acceptance criteria" section.
5. Use the file/folder layout, class names, and `Theme/Colors.swift`, `Theme/Fonts.swift`, `Theme/Metrics.swift` values from `PRD.md` exactly — do not rename, restructure, or substitute.
6. Use `grep`, `find`, `ls`, and `read` to navigate code added by previous iterations. Do not duplicate work that prior iterations completed.
7. Stay within the chosen issue's scope. Do not implement other issues' acceptance criteria opportunistically — even if it would only take a moment.

**Files you must never modify**: `PRD.md`, `PROMPT.md`, `ralph.sh`, `.gitignore`, `notepad.png`.

---

## Step 3 — Build & verify

Run the build:

```
xcodebuild -project Notepad.xcodeproj -scheme Notepad build 2>&1 | tail -200
```

Capture the exit code. If the chosen issue's acceptance criteria mention unit tests (look for "unit tests", "XCTest", "NotepadTests"), also run:

```
xcodebuild -project Notepad.xcodeproj -scheme Notepad test 2>&1 | tail -200
```

**If build or tests fail (non-zero exit)**:

1. Do NOT commit, do NOT push, do NOT close the issue.
2. Capture the last 30 lines of relevant error output.
3. Comment on the issue:
   ```
   gh issue comment <N> --repo samantha-network4all-bot/slate --body "Automated attempt failed during build/tests.

   <suspected-cause-one-line>

   Last 30 lines:
   \`\`\`
   <error-output>
   \`\`\`
   "
   ```
4. Write `failed:<N>` to `.ralph-status`.
5. Print `[ralph] iter result: failed:<N>` and stop.

---

## Step 4 — Submit & close (only if build/tests passed)

1. Stage everything:
   ```
   git add -A
   ```
2. Safety check — refuse to proceed if any of these are staged:
   ```
   git diff --cached --name-only | grep -E '\.(env|key|pem)$|secrets|credentials' && exit 1 || true
   ```
3. Commit with a message that references the issue:
   ```
   git commit -m "<S-slice-tag>: <one-line summary>

   Closes #<N>
   "
   ```
   Example tag: `S1` for issue #2, `S2` for issue #3, etc. Extract the `S-slice-tag` from the issue title prefix (titles start with `S<num>:`).
4. Push to main:
   ```
   git push origin main
   ```
5. **If `git push` fails** (e.g., non-fast-forward rejection): do NOT force-push. Comment on the issue with the push error, write `failed:<N>` to `.ralph-status`, and stop.
6. Close the issue:
   ```
   SHA=$(git rev-parse --short HEAD)
   gh issue close <N> --repo samantha-network4all-bot/slate \
     --comment "Implemented and merged in $SHA via automated Ralph loop."
   ```
   If `gh issue close` fails after a successful push, still write `closed:<N>` — the push is the source of truth; the issue can be closed manually.
7. Write `closed:<N>` to `.ralph-status`.
8. Print `[ralph] iter result: closed:<N>` and stop.

---

## Hard rules

- **One iteration = one issue.** Never attempt to chain multiple issues in one run.
- **Never** force-push. **Never** rewrite history. **Never** delete files outside the working directory.
- **Never** modify `PRD.md`, `PROMPT.md`, `ralph.sh`, `.gitignore`, `notepad.png`.
- **Never** commit `.env`, `*.key`, `*.pem`, or anything matching `secrets|credentials`.
- **Never** push to a branch other than `main`.
- **Never** ask the user a question — if you're stuck, write `failed:<N>` with a comment explaining the blocker.
- The `.ralph-status` file is mandatory. Write it before exiting in **every** code path.
