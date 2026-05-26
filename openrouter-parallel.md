# Ralph: OpenRouter + Parallel Execution

## Overview

Two upgrades to the Ralph autonomous coding loop:

1. **OpenRouter variant** (`ralph-openrouter.sh`) — sequential loop using OpenRouter-hosted models (Claude Sonnet, etc.) instead of the default Ollama/Qwen.
2. **Parallel execution** (`ralph-parallel.sh`) — spawns N workers in isolated git worktrees, each running its own pi instance, coordinating issue selection via GitHub labels.

All variants use the `in-progress` GitHub label to coordinate and avoid picking the same issue.

---

## Files changed / created

| File | Action | Purpose |
|------|--------|---------|
| `PROMPT.md` | Edited | Added `in-progress` label filtering, adding, and removal |
| `ralph.sh` | Edited | Added `gh label create` preflight (3 lines) |
| `ralph-openrouter.sh` | Created | Sequential loop with OpenRouter default model |
| `PROMPT-parallel.md` | Created | Parallel-specific prompt (branch+PR workflow) |
| `ralph-parallel.sh` | Created | Parallel orchestrator spawning N worker processes |
| `openrouter-parallel.md` | Created | This document |

---

## Design decisions

### Coordinate via `in-progress` label
- Every Ralph variant (sequential or parallel) adds the `in-progress` label to an issue before working on it and removes it after closing/failing.
- Workers filter out issues with `in-progress` so no two workers pick the same issue.
- If a worker crashes mid-flight, the label remains — requires manual cleanup but guarantees safety.

### Sequential variants push directly to `main` (unchanged)
- `ralph.sh` and `ralph-openrouter.sh` keep the existing workflow: commit on main, push to main, close issue.
- They are fully compatible with parallel workers because they also use the `in-progress` label.

### Parallel variant uses feature branches + PRs
- Each parallel worker gets its own git worktree (`../notepad-worker-<i>/`) and branch (`ralph/w<i>`).
- Workers commit to their branch, push, create a PR targeting `main`, squash-merge it.
- After merge, the worker resets its branch to the new `origin/main` and loops.
- This avoids merge conflicts between workers pushing to the same branch.

### Mix-and-match models across workers
- Each parallel worker can have its own provider/model via env vars:
  ```
  RALPH_WORKER_0_ARGS="--provider openrouter --model anthropic/claude-sonnet-4-20250514"
  RALPH_WORKER_1_ARGS="--provider ollama --model qwen/qwen3.6-27b"
  ```
- If unset, a worker uses pi's default provider/model.

### Default OpenRouter model
- `anthropic/claude-sonnet-4-20250514` — configurabled via `RALPH_MODEL` env var.

---

## Usage examples

```bash
# Sequential with OpenRouter (Claude Sonnet by default)
./ralph-openrouter.sh

# Sequential with OpenRouter, specific model
RALPH_MODEL="anthropic/claude-haiku-4-20250514" ./ralph-openrouter.sh

# Sequential with OpenRouter, extra pi flags
PI_ARGS="--thinking high" ./ralph-openrouter.sh

# 3 parallel workers, all using default model
./ralph-parallel.sh -w 3

# 2 parallel workers, mix-and-match
RALPH_WORKER_0_ARGS="--provider openrouter --model anthropic/claude-sonnet-4-20250514" \
RALPH_WORKER_1_ARGS="" \
./ralph-parallel.sh -w 2

# Original sequential loop (unchanged, backward compatible)
./ralph.sh
```

---

## Preflight requirements

All scripts require:
- `pi` CLI on PATH (version 0.75.5+)
- `gh` authenticated (`gh auth status`)
- `git` on PATH
- `jq` on PATH (used by `ralph-format.sh`)
- `timeout` or `gtimeout` (coreutils) on PATH

The `in-progress` label is auto-created in the repo if missing.
