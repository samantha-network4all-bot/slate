# Ralph — manual

## Overview

Three scripts automate issue implementation via the `pi` CLI:

| Script | Mode | Model | Git strategy |
|--------|------|-------|-------------|
| `ralph.sh` | Sequential | Ollama (default) | Push to `main` directly |
| `ralph-openrouter.sh` | Sequential | OpenRouter (Claude Sonnet default) | Push to `main` directly |
| `ralph-parallel.sh` | Parallel (N workers) | Per-worker config | Feature branches + PRs |

All three coordinate via the `in-progress` GitHub label.

---

## Usage

```bash
# Sequential, Ollama (original)
./ralph.sh

# Sequential, OpenRouter
./ralph-openrouter.sh

# Sequential, OpenRouter with specific model
RALPH_MODEL="anthropic/claude-haiku-4-20250514" ./ralph-openrouter.sh

# Extra pi flags for any sequential variant
PI_ARGS="--thinking high" ./ralph-openrouter.sh

# 3 parallel workers
./ralph-parallel.sh -w 3

# Mix-and-match models
RALPH_WORKER_0_ARGS="--provider openrouter --model anthropic/claude-sonnet-4-20250514" \
RALPH_WORKER_1_ARGS="--provider ollama --model qwen/qwen3.6-27b" \
./ralph-parallel.sh -w 2

# Limit iterations
./ralph.sh 5
```

---

## What happens when you break a running loop

### Ctrl+C during `ralph.sh` / `ralph-openrouter.sh`

| What happens | Recovery |
|---|---|
| Working dir has uncommitted changes | Next iteration picks them up — the AI is told to treat them as in-progress work |
| `in-progress` label stays on the issue | **Manual cleanup needed** — run `gh issue edit <N> --remove-label in-progress` |
| No `.ralph-status` written | Next iteration runs Step 1 fresh — may pick a *different* issue on top of half-finished code from the interrupted one |

**Recovery after breaking sequential:**
```bash
# 1. See what's dirty
git status

# 2. Stash any half-finished work so the next iteration starts clean
git stash

# 3. Find orphaned in-progress labels
gh issue list --label in-progress --repo samantha-network4all-bot/slate --json number

# 4. Clear them
gh issue edit <N> --remove-label in-progress

# 5. Restart
./ralph.sh
```

### Ctrl+C during `ralph-parallel.sh`

The trap handler runs automatically and cleans up worktrees. The script's trap handler:
- Removes each worktree (`../notepad-worker-<i>/`)
- Deletes each worker branch (`ralph/w<i>`)
- `in-progress` labels are **not** auto-cleaned

**Recovery after breaking parallel:**
```bash
# 1. Clean up any leftover worktree directories
rm -rf ../notepad-worker-*/

# 2. Delete leftover branches
git branch -D ralph/w0 ralph/w1 2>/dev/null

# 3. Find orphaned in-progress labels
gh issue list --label in-progress --repo samantha-network4all-bot/slate --json number

# 4. Clear them
for num in $(gh issue list --label in-progress --repo samantha-network4all-bot/slate --json number -q '.[].number'); do
  gh issue edit "$num" --remove-label in-progress
done

# 5. Restart
./ralph-parallel.sh -w 2
```

---

## File layout

```
notepad/
├── ralph.sh                  # Sequential Ollama loop
├── ralph-openrouter.sh       # Sequential OpenRouter loop
├── ralph-parallel.sh         # Parallel orchestrator
├── ralph-format.sh           # JSON→human formatter (used by all three)
├── PROMPT.md                 # Prompt for sequential variants
├── PROMPT-parallel.md        # Prompt for parallel workers
├── PRD.md                    # Product spec
├── manual.md                 # This file
├── openrouter-parallel.md    # Design document
├── .gitignore
├── notepad.png               # Reference image
│
├── .ralph-logs/              # Per-iteration raw JSON logs (sequential)
├── buidlog-pi.log            # Aggregated pretty log (sequential)
│
└── (parallel workers live outside in ../notepad-worker-<i>/)
```

---

## Per-worker configuration

Parallel workers read args from `RALPH_WORKER_<ID>_ARGS` env vars. If unset, the worker uses pi's default provider/model. The args are injected into the `pi` command **before** the iteration message, so they can specify provider, model, thinking level, etc.

Examples:

```bash
# Worker 0 uses Claude Sonnet, worker 1 uses default (Ollama)
RALPH_WORKER_0_ARGS="--provider openrouter --model anthropic/claude-sonnet-4-20250514" \
./ralph-parallel.sh -w 2

# All workers use the same model via PI_ARGS (applied to all)
PI_ARGS="--provider openrouter --model anthropic/claude-haiku-4-20250514" \
./ralph-parallel.sh -w 3
```

---

## Logs

**Sequential:**
- `buidlog-pi.log` — human-readable progress (tail -f me)
- `.ralph-logs/iter-<N>-<timestamp>.json` — raw pi JSON per iteration
- `.ralph-logs/latest.json` — symlink to most recent iteration

**Parallel:**
- `ralph-parallel.log` — orchestrator log (worker start/stop/errors)
- `../notepad-worker-<i>/buidlog-pi.log` — per-worker progress
- `../notepad-worker-<i>/.ralph-logs/iter-<N>-<timestamp>.json` — per-worker raw JSON

---

## Requirements

- `pi` CLI (0.75.5+) on PATH
- `gh` authenticated (`gh auth login`)
- `git` on PATH
- `jq` on PATH (`brew install jq`)
- `timeout` or `gtimeout` (`brew install coreutils`)
- `ralph-format.sh` executable alongside the script
- `PROMPT.md` in the working directory (for sequential) or `PROMPT-parallel.md` (for parallel)

The `in-progress` label is created automatically in the repo if missing.
