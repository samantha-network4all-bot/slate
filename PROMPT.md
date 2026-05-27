# Ralph iteration prompt

You are running **one iteration** of an autonomous loop. The wrapper script (`ralph.sh`) re-invokes you fresh each time with no prior session. Do not try to do more than one issue per iteration. Do not ask the user questions — make the reasonable call and proceed.

Your final action every iteration **must** be writing one line to `.ralph-status`:

- `empty` — no eligible issue exists; the loop will stop.
- `closed:<N>` — you successfully implemented and closed issue `#N`.
- `failed:<N>` — you tried issue `#N` but build/tests/push failed; you commented on it and left it open.

---

## Tool-use discipline (read this first)

Use the runtime's native tool-call protocol. **Do not emit literal `<tool_call>`, `<function=…>`, or any other plain-text tool-call syntax** in your reasoning or output — the runtime ignores it and the turn is wasted. If you need to do something, call the appropriate tool (`bash`, `read`, `edit`, `write`, `grep`, `find`, `ls`) via the normal mechanism. If you find yourself "writing" what a command would do, stop and actually invoke it.

When you call `bash`, prefer short, single-purpose commands over long pipelines so failures are easier to diagnose. Capture only the tail of large outputs (`| tail -50`).

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
2. Any label is `awaiting-human-review` (already handed off to a human; do not re-pick).
3. The body's `## Blocked by` section lists any `#N` reference whose state is **not** `closed`. Verify each blocker with:
   ```
   gh issue view <N> --repo samantha-network4all-bot/slate --json state
   ```
   Skip the candidate if any blocker is still `OPEN`.

Pick the **first** candidate that survives all filters.

> **HITL issues** (title contains `HITL` or `(HITL`) are **not** auto-skipped. Implement them normally, but follow the **HITL handoff path** in Step 4 instead of pushing to `main`. Set a local flag `IS_HITL=1` so you remember to branch later.

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

### Bootstrapping the Xcode project

The Xcode project is generated from `Project.yml` by `xcodegen` — **never hand-edit `Notepad.xcodeproj/project.pbxproj`**. If you need a new target, source folder, or build setting, edit `Project.yml` and re-run `xcodegen generate`.

Before building, ensure the project file exists:

```
[ -f Notepad.xcodeproj/project.pbxproj ] || xcodegen generate
```

If `xcodegen` fails or is missing, that is a fatal error for this iteration — comment on the issue with the error and write `failed:<N>`.

### Build

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
4. Push:

   **── HITL handoff branch ──**

   If `IS_HITL=1` (the issue title contained `HITL`), **do NOT push to main**. Instead push to a review branch and open a PR for human sign-off:

   a. Move the just-made commit onto a review branch and push it:
      ```
      git checkout -b review/<N>
      git push -u origin review/<N>
      # restore main so the next iteration starts clean
      git checkout main
      git reset --hard origin/main
      ```

   b. Ensure the label exists, then open a PR:
      ```
      gh label create awaiting-human-review --repo samantha-network4all-bot/slate \
        --color "0e8a16" --description "PR built green; waiting on human visual sign-off" 2>/dev/null || true
      PR_URL=$(gh pr create --repo samantha-network4all-bot/slate --base main \
        --head review/<N> --fill)
      PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')
      gh pr edit "$PR_NUM" --repo samantha-network4all-bot/slate --add-label awaiting-human-review
      ```

   c. Write the close-comment to `/tmp/ralph-review-<N>.md` using the same template as step 6 below, but with this **first** section prepended:
      ```markdown
      **HITL handoff** — implementation complete, build green, **PR open for human review**: <PR_URL>

      A human must verify the visual/behavior acceptance criteria and merge the PR. Do not re-open this issue; track follow-up on the PR.
      ```

   d. Post the comment and close the issue:
      ```
      gh issue comment <N> --repo samantha-network4all-bot/slate --body-file /tmp/ralph-review-<N>.md
      gh issue close   <N> --repo samantha-network4all-bot/slate --reason completed
      ```

   e. Write `review:<N>` to `.ralph-status`, print `[ralph] iter result: review:<N>`, and stop. **Skip steps 5–8.**

   **── end HITL handoff ──**

   Otherwise (non-HITL), push to main:
   ```
   git push origin main
   ```
5. **If `git push` fails** (e.g., non-fast-forward rejection): do NOT force-push. Comment on the issue with the push error, write `failed:<N>` to `.ralph-status`, and stop.
6. **Post a detailed completion comment, then close.** A bare "closed" comment is not acceptable — the user reads these comments to learn what shipped without opening the diff. Build the comment body in a temp file first (so multi-line markdown survives shell quoting), then post + close:

   ```
   SHA=$(git rev-parse --short HEAD)
   FILES=$(git diff --name-only HEAD~1..HEAD | sed 's/^/- `/' | sed 's/$/`/')
   BUILD_TAIL=$(xcodebuild -project Notepad.xcodeproj -scheme Notepad build 2>&1 | tail -5)
   # If you ran tests, also capture: TEST_TAIL=$(xcodebuild ... test 2>&1 | tail -5)
   ```

   Then use the `write` tool to write the following template to `/tmp/ralph-close-<N>.md`, filling in every section. **Do not skip sections.** Mark every acceptance criterion either `[x]` (done + how you verified) or `[ ]` (with an honest reason it was deferred):

   ```markdown
   **Implemented in `<short SHA>`** via automated Ralph loop · model: `<provider>/<model>`

   ## Summary
   <2–4 sentences in your own words: what this slice now does end-to-end, the user-visible behavior, and any non-obvious implementation choices.>

   ## Acceptance criteria — verification
   <Copy every `- [ ]` bullet from the issue body. For each, change to `- [x]` and append ` — <one-line evidence>` describing how you verified it (built and ran, manual test, code inspection, test name).>

   ## Build
   ```
   xcodebuild -project Notepad.xcodeproj -scheme Notepad build  →  exit 0
   ```
   Last lines:
   ```
   <BUILD_TAIL>
   ```

   ## Tests
   <One of:
    - `N XCTest cases passed in NotepadTests/<file>.swift` plus the relevant tail, OR
    - `No unit tests required by this slice's acceptance criteria.`>

   ## Files changed (this commit)
   <FILES list>

   ## Notes / follow-ups
   <Anything the next iteration or a reviewer should know: known limitations, TODOs, deviations from the PRD with rationale. Write "None." if there's nothing.>
   ```

   Then post and close:

   ```
   gh issue comment <N> --repo samantha-network4all-bot/slate --body-file /tmp/ralph-close-<N>.md
   gh issue close   <N> --repo samantha-network4all-bot/slate --reason completed
   ```

   If `gh issue comment` succeeds but `gh issue close` fails, still write `closed:<N>` — the comment + push are the source of truth; the issue can be closed manually.

   If `gh issue comment` itself fails (rate limit, network), fall through to `gh issue close <N> --comment "Implemented in $SHA — comment body in $(pwd)/.ralph-logs/close-<N>.md"` and copy the temp file to that path as a backup.
7. Write `closed:<N>` to `.ralph-status`.
8. Print `[ralph] iter result: closed:<N>` and stop.

---

## Hard rules

- **One iteration = one issue.** Never attempt to chain multiple issues in one run.
- **Never** force-push. **Never** rewrite history. **Never** delete files outside the working directory.
- **Never** modify `PRD.md`, `PROMPT.md`, `ralph.sh`, `.gitignore`, `notepad.png`.
- **Never** commit `.env`, `*.key`, `*.pem`, or anything matching `secrets|credentials`.
- **Never** push to a branch other than `main` — *except* for `review/<N>` branches created by the HITL handoff path in Step 4.
- **Never** ask the user a question — if you're stuck, write `failed:<N>` with a comment explaining the blocker.
- The `.ralph-status` file is mandatory. Write it before exiting in **every** code path.
