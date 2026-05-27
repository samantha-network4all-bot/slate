#!/usr/bin/env bash
# ralph-parallel.sh — Parallel Ralph worker pool for Notepad issue execution.
# Spawns N workers in isolated git worktrees, each running its own pi instance.
# Workers coordinate via the `in-progress` GitHub label to avoid picking the
# same issue. Each worker uses feature branches + PRs to merge into main.
#
# Usage:
#   ./ralph-parallel.sh [-w NUM_WORKERS] [MAX_ITERATIONS]
#
# Env:
#   RALPH_WORKERS            number of parallel workers (default 2, overridden by -w)
#   RALPH_WORKER_0_ARGS      extra pi args for worker 0 (e.g. "--provider openrouter --model ...")
#   RALPH_WORKER_1_ARGS      extra pi args for worker 1
#   RALPH_WORKER_2_ARGS      ...and so on up to the worker count
#   RALPH_ITER_TIMEOUT       seconds per iteration per worker (default 7200)
#   RALPH_REPO               override GitHub repo (default samantha-network4all-bot/slate)
#   RALPH_MAX                max iterations per worker (default 9999)
#
# The parent orchestrator:
#   1. Creates a git worktree per worker under ../notepad-worker-<i>/
#   2. Each worker gets branch ralph/w<i> based on origin/main
#   3. Workers copy PROMPT-parallel.md as their PROMPT.md
#   4. Workers run pi independently, each in their own loop
#   5. When all workers finish, worktrees are cleaned up

set -euo pipefail

# ---------- config ----------

readonly REPO="${RALPH_REPO:-samantha-network4all-bot/slate}"
readonly ITER_TIMEOUT="${RALPH_ITER_TIMEOUT:-7200}"
MAX="${RALPH_MAX:-9999}"
readonly LOG_FILE="ralph-parallel.log"
readonly MAIN_PROMPT_FILE="PROMPT-parallel.md"

# Parse -w flag
NUM_WORKERS="${RALPH_WORKERS:-2}"
while getopts ":w:h" opt; do
  case "$opt" in
    w) NUM_WORKERS="$OPTARG" ;;
    h)
      echo "Usage: $0 [-w NUM_WORKERS] [MAX_ITERATIONS]"
      echo ""
      echo "Env:"
      echo "  RALPH_WORKERS            number of workers (default 2)"
      echo "  RALPH_WORKER_<i>_ARGS    per-worker pi args (e.g. '--provider openrouter --model ...')"
      echo "  RALPH_ITER_TIMEOUT       seconds per iteration (default 7200)"
      echo "  RALPH_REPO               GitHub repo (default samantha-network4all-bot/slate)"
      exit 0
      ;;
    \?) echo "Unknown flag -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# Allow MAX as positional arg
readonly MAX="${1:-$MAX}"

# ---------- preflight ----------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PARENT_DIR="$(dirname "$SCRIPT_DIR")"

[[ -f "$MAIN_PROMPT_FILE" ]] || { echo "ralph-parallel: $MAIN_PROMPT_FILE missing" >&2; exit 2; }

command -v pi >/dev/null   || { echo "ralph-parallel: 'pi' not on PATH" >&2; exit 2; }
command -v gh >/dev/null   || { echo "ralph-parallel: 'gh' not on PATH" >&2; exit 2; }
command -v git >/dev/null  || { echo "ralph-parallel: 'git' not on PATH" >&2; exit 2; }
command -v jq >/dev/null   || { echo "ralph-parallel: 'jq' not on PATH (brew install jq)" >&2; exit 2; }

[[ -x "./ralph-format.sh" ]] || { echo "ralph-parallel: ralph-format.sh not executable" >&2; exit 2; }

# Prefer GNU `timeout`; fall back to `gtimeout` (Homebrew coreutils).
if command -v timeout >/dev/null; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null; then
  TIMEOUT_BIN=gtimeout
else
  echo "ralph-parallel: neither 'timeout' nor 'gtimeout' on PATH (brew install coreutils)" >&2
  exit 2
fi

gh auth status >/dev/null 2>&1 \
  || { echo "ralph-parallel: gh is not authenticated (run: gh auth login)" >&2; exit 2; }

# Ensure the in-progress label exists for worker coordination.
gh label create in-progress --repo "$REPO" \
  --color "fbca04" --description "Being worked on by a Ralph worker" 2>/dev/null || true

# Ensure we're in a git repo with a remote.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ralph-parallel: not inside a git repo — run from the notepad directory" >&2
  exit 2
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ralph-parallel: no 'origin' remote configured" >&2
  exit 2
fi

log() {
  local msg="$1"
  echo "[$(date '+%F %T')] $msg" | tee -a "$LOG_FILE"
}

log "ralph-parallel: starting $NUM_WORKERS workers"

# ---------- worktree setup ----------

WORKTREES=()
WORKTREE_DIRS=()
for ((i = 0; i < NUM_WORKERS; i++)); do
  worktree_dir="$PARENT_DIR/notepad-worker-${i}"
  branch="ralph/w${i}"

  WORKTREES+=("$worktree_dir")
  WORKTREE_DIRS+=("$worktree_dir")

  # Remove prior worktree cleanly if it exists
  git worktree remove "$worktree_dir" 2>/dev/null || true
  git branch -D "$branch" 2>/dev/null || true
  rm -rf "$worktree_dir"

  log "worker $i: creating worktree at $worktree_dir (branch $branch)"

  git fetch origin main 2>>"$LOG_FILE" || true
  git worktree add "$worktree_dir" -b "$branch" origin/main \
    >>"$LOG_FILE" 2>&1 || {
    log "worker $i: failed to create worktree"
    exit 2
  }

  # Copy prompt and formatter into the worktree
  cp "$MAIN_PROMPT_FILE" "$worktree_dir/PROMPT.md"
  cp ralph-format.sh "$worktree_dir/"
  cp PRD.md "$worktree_dir/" 2>/dev/null || true
  chmod +x "$worktree_dir/ralph-format.sh"
done

# ---------- cleanup trap ----------

cleanup() {
  log "cleaning up worktrees..."
  for wd in "${WORKTREE_DIRS[@]}"; do
    git worktree remove "$wd" 2>/dev/null || true
    rm -rf "$wd" 2>/dev/null || true
  done
  # Delete worker branches
  for ((i = 0; i < NUM_WORKERS; i++)); do
    git branch -D "ralph/w${i}" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

# ---------- worker function ----------

# Runs in a background subshell. All variables are local by design.
ralph_worker() {
  local id="$1"
  local worktree="$2"
  local worker_args="$3"
  local worker_max="$4"
  local worker_timeout="$5"
  local worker_repo="$6"
  local timeout_bin="$7"

  # Redirect all worker stdout/stderr through the parent's pipe line
  # so the terminal isn't garbled. We write to the worker's own files.
  local log_file="$worktree/buidlog-pi.log"
  local raw_log_dir="$worktree/.ralph-logs"
  local status_file="$worktree/.ralph-status"
  local formatter="$worktree/ralph-format.sh"
  local prompt_file="$worktree/PROMPT.md"

  mkdir -p "$raw_log_dir"

  # Move into the worktree
  cd "$worktree"

  local unknown_streak=0

  for ((iter = 1; iter <= worker_max; iter++)); do
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local raw_log="$raw_log_dir/iter-${iter}-${ts}.json"

    # Reset worker branch to latest main (other workers may have merged)
    git fetch origin main >>"$log_file" 2>&1 || true
    git checkout -B "ralph/w${id}" origin/main >>"$log_file" 2>&1

    local banner
    banner="── worker[$id] iter $iter / $worker_max · $(date '+%F %T') · repo=$worker_repo · timeout=${worker_timeout}s ──"
    echo "$banner"
    echo "$banner" >> "$log_file"

    if [[ ! -f "$prompt_file" ]]; then
      echo "worker[$id]: PROMPT.md missing at $prompt_file, bailing" >&2
      return 4
    fi
    local prompt_head
    prompt_head=$(head -n 1 "$prompt_file")
    echo "worker[$id]: prompt ok ($(wc -l <"$prompt_file" | tr -d ' ') lines) — first line: $prompt_head" | tee -a "$log_file"

    rm -f "$status_file"

    set +o pipefail
    set +e
    "$timeout_bin" "$worker_timeout" pi --print --no-session --mode json \
      --append-system-prompt "$prompt_file" \
      --tools read,bash,edit,write,grep,find,ls \
      $worker_args \
      "Run one Ralph iteration on worker branch ralph/w${id}. Working repo is $worker_repo. Follow PROMPT.md exactly. End by writing .ralph-status." \
      2>>"$log_file" \
      | tee "$raw_log" \
      | "$formatter" \
      | tee -a "$log_file"
    local pi_rc=${PIPESTATUS[0]}
    set -e
    set -o pipefail

    ln -sfn "$(basename "$raw_log")" "$raw_log_dir/latest.json"

    # Detect LLM connection failures: pi emitted only error stop_reasons and zero tokens.
    if [[ -s "$raw_log" ]] \
       && ! grep -q '"stopReason":"end_turn"\|"stopReason": "end_turn"\|"stopReason":"tool_use"\|"stopReason": "tool_use"' "$raw_log" \
       && grep -q '"errorMessage"' "$raw_log"; then
      local err_msg
      err_msg=$(grep -o '"errorMessage":"[^"]*"' "$raw_log" | head -n 1 | sed 's/.*":"//;s/"$//')
      echo "worker[$id]: iter $iter -> LLM unreachable (${err_msg:-unknown error}), bailing" >&2
      return 5
    fi

    local status
    status=$(cat "$status_file" 2>/dev/null || echo "missing")

    case "$status" in
      empty)
        echo "worker[$id]: iter $iter -> empty (no eligible issues). stopping."
        return 0
        ;;
      closed:*|failed:*|review:*)
        echo "worker[$id]: iter $iter -> $status (pi exit=$pi_rc)"
        unknown_streak=0
        ;;
      missing|*)
        unknown_streak=$((unknown_streak + 1))
        echo "worker[$id]: iter $iter -> unexpected status '$status' (pi exit=$pi_rc), streak=$unknown_streak/3"
        if (( unknown_streak >= 3 )); then
          echo "worker[$id]: 3 consecutive unknown statuses, bailing" >&2
          return 3
        fi
        ;;
    esac

    sleep 2
  done

  echo "worker[$id]: hit max=$worker_max iterations, stopping"
  return 0
}

# ---------- launch workers ----------

PIDS=()
for ((i = 0; i < NUM_WORKERS; i++)); do
  args_var="RALPH_WORKER_${i}_ARGS"
  worker_args="${!args_var:-}"

  # Build the explicit worker_args string
  ralph_worker "$i" "${WORKTREES[$i]}" "$worker_args" "$MAX" "$ITER_TIMEOUT" "$REPO" "$TIMEOUT_BIN" &
  PIDS+=($!)
  log "worker $i launched (PID $!) in ${WORKTREES[$i]}"
done

# ---------- wait for all workers ----------

OVERALL_RC=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || OVERALL_RC=$?
done

log "all workers finished (exit $OVERALL_RC)"

exit $OVERALL_RC
