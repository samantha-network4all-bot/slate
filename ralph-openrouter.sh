#!/usr/bin/env bash
# ralph-openrouter.sh — Ralph loop for Notepad issue execution via OpenRouter.
# Invokes `pi --print` in a loop using OpenRouter-hosted models, where each
# iteration picks the next eligible GitHub issue, implements it, builds,
# commits, pushes, and closes it. Stops when no eligible issue remains.
#
# Usage:
#   ./ralph-openrouter.sh [-s] [MAX_ITERATIONS]
#
# Flags:
#   -s  Interactively pick a free OpenRouter model before starting the loop.
#
# Env:
#   PI_ARGS              extra args passed to `pi` (e.g. "--thinking high")
#   RALPH_MODEL          OpenRouter model override (default openrouter/free)
#   RALPH_ITER_TIMEOUT   seconds per iteration (default 1800)
#   RALPH_REPO           override GitHub repo (default samantha-network4all-bot/slate)
#
# Stops the loop early if pi writes `.ralph-status` with content `empty`,
# or if more than 3 consecutive iterations return an unknown/missing status.

set -euo pipefail

SELECT_MODEL=0
while getopts ":sh" opt; do
  case "$opt" in
    s) SELECT_MODEL=1 ;;
    h)
      echo "Usage: $0 [-s] [MAX_ITERATIONS]"
      echo "  -s  Pick a free OpenRouter model interactively before starting."
      exit 0
      ;;
    \?) echo "Unknown flag -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

readonly REPO="${RALPH_REPO:-samantha-network4all-bot/slate}"
readonly MAX="${1:-9999}"
readonly ITER_TIMEOUT="${RALPH_ITER_TIMEOUT:-7200}"
readonly STATUS_FILE=".ralph-status"
readonly PROMPT_FILE="PROMPT.md"
readonly LOG_FILE="buildlog-pi.log"          # aggregated pretty log; `tail -f` me
readonly RAW_LOG_DIR=".ralph-logs"          # per-iteration raw pi json
readonly FORMATTER="./ralph-format.sh"

# OpenRouter defaults
DEFAULT_MODEL="${RALPH_MODEL:-openrouter/free}"

# ---------- free model picker (-s) ----------

pick_free_model() {
  echo "ralph: fetching free OpenRouter models..." >&2
  local json
  json=$(curl -fsS https://openrouter.ai/api/v1/models) || {
    echo "ralph: failed to fetch OpenRouter model list" >&2
    return 1
  }

  # Free = prompt price and completion price both "0" (strings in the API).
  local -a ids names ctxs
  while IFS=$'\t' read -r id name ctx; do
    ids+=("$id")
    names+=("$name")
    ctxs+=("$ctx")
  done < <(echo "$json" | jq -r '
    .data
    | map(select((.pricing.prompt == "0") and (.pricing.completion == "0")))
    | sort_by(-(.context_length // 0))
    | .[] | [.id, .name, (.context_length // 0)] | @tsv')

  local count=${#ids[@]}
  if (( count == 0 )); then
    echo "ralph: no free models returned from OpenRouter" >&2
    return 1
  fi

  echo "" >&2
  echo "Free OpenRouter models ($count):" >&2
  local i
  for ((i = 0; i < count; i++)); do
    printf "  [%2d] %-60s ctx=%s\n" "$((i + 1))" "${ids[i]}" "${ctxs[i]}" >&2
  done

  local choice=""
  while :; do
    printf "Select model [1-%d] (default 1): " "$count" >&2
    read -r choice </dev/tty || { echo "" >&2; return 1; }
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      break
    fi
    echo "ralph: invalid selection '$choice'" >&2
  done

  DEFAULT_MODEL="${ids[$((choice - 1))]}"
  echo "ralph: using model $DEFAULT_MODEL" >&2
}

if (( SELECT_MODEL == 1 )); then
  pick_free_model || exit 2
fi

# ---------- preflight ----------

cd "$(dirname "$0")"

[[ -f "$PROMPT_FILE" ]] || { echo "ralph: $PROMPT_FILE missing in $(pwd)" >&2; exit 2; }

command -v pi >/dev/null   || { echo "ralph: 'pi' not on PATH" >&2; exit 2; }
command -v gh >/dev/null   || { echo "ralph: 'gh' not on PATH" >&2; exit 2; }
command -v git >/dev/null  || { echo "ralph: 'git' not on PATH" >&2; exit 2; }
command -v jq >/dev/null   || { echo "ralph: 'jq' not on PATH (brew install jq)" >&2; exit 2; }
command -v curl >/dev/null || { echo "ralph: 'curl' not on PATH" >&2; exit 2; }
[[ -x "$FORMATTER" ]]      || { echo "ralph: $FORMATTER not executable" >&2; exit 2; }
mkdir -p "$RAW_LOG_DIR"

# Prefer GNU `timeout`; fall back to `gtimeout` (Homebrew coreutils).
if command -v timeout >/dev/null; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null; then
  TIMEOUT_BIN=gtimeout
else
  echo "ralph: neither 'timeout' nor 'gtimeout' on PATH (brew install coreutils)" >&2
  exit 2
fi

gh auth status >/dev/null 2>&1 \
  || { echo "ralph: gh is not authenticated (run: gh auth login)" >&2; exit 2; }

# Ensure the in-progress label exists for worker coordination.
gh label create in-progress --repo "$REPO" \
  --color "fbca04" --description "Being worked on by a Ralph worker" 2>/dev/null || true

# ---------- git bootstrap (idempotent) ----------
# If the working dir isn't a git repo yet, initialize and push the seed files
# (PRD, prompt, script, gitignore, reference image) to origin/main on the slate
# repo. The script never touches main on a repo that already has a different
# remote configured; it only fills in missing pieces.

readonly DEFAULT_REMOTE="https://github.com/samantha-network4all-bot/slate.git"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ralph: bootstrap: git init"
  git init -q
  git checkout -q -b main 2>/dev/null || git switch -q -c main 2>/dev/null || true
fi

# Ensure we're on a branch called main; create if missing.
if ! git rev-parse --verify main >/dev/null 2>&1; then
  git checkout -q -b main 2>/dev/null || git switch -q -c main
fi
current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo)"
if [[ "$current_branch" != "main" ]]; then
  echo "ralph: bootstrap: switching to main (was '$current_branch')"
  git checkout -q main
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ralph: bootstrap: adding origin -> $DEFAULT_REMOTE"
  git remote add origin "$DEFAULT_REMOTE"
fi

# If no commits exist yet, create the seed commit and push.
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "ralph: bootstrap: seed commit"
  git add .gitignore PRD.md PROMPT.md PROMPT-parallel.md manual.md ralph.sh ralph-openrouter.sh ralph-parallel.sh ralph-format.sh notepad.png 2>/dev/null || true
  git -c user.email="ralph@local" -c user.name="ralph-loop" \
    commit -q -m "Bootstrap: PRD, ralph loop, prompt, gitignore"
fi

# If main has no upstream yet, push and set tracking.
if ! git rev-parse --verify --quiet origin/main >/dev/null 2>&1; then
  echo "ralph: bootstrap: pushing initial main -> origin"
  git push -u origin main
fi

# ---------- loop ----------

# Read $PI_ARGS as an array so flags survive word-splitting cleanly.
read -r -a PI_ARGS_ARR <<<"${PI_ARGS:-}"

unknown_streak=0

for ((i = 1; i <= MAX; i++)); do
  ts="$(date +%Y%m%d-%H%M%S)"
  raw_log="$RAW_LOG_DIR/iter-${i}-${ts}.json"

  banner="── ralph-openrouter iter $i / $MAX · $(date '+%F %T') · repo=$REPO · model=$DEFAULT_MODEL · timeout=${ITER_TIMEOUT}s ──"
  echo "$banner"
  echo "$banner" >> "$LOG_FILE"
  rm -f "$STATUS_FILE"

  # Pi is invoked fresh each iteration (--no-session) and emits JSON events
  # to stdout. Stderr (backend errors, startup noise) goes straight to the
  # aggregated log. Stdout is teed raw to a per-iteration json log AND
  # passed through the formatter for human-readable progress, which is then
  # teed to both the terminal and the aggregated log.
  # NOTE: --provider/--model come BEFORE PI_ARGS_ARR so user overrides
  # via PI_ARGS take precedence (last value wins).
  set +o pipefail
  set +e
  "$TIMEOUT_BIN" "$ITER_TIMEOUT" pi --print --no-session --mode json \
    --provider openrouter --model "$DEFAULT_MODEL" \
    --append-system-prompt "$PROMPT_FILE" \
    --tools read,bash,edit,write,grep,find,ls \
    ${PI_ARGS_ARR[@]+"${PI_ARGS_ARR[@]}"} \
    "Run one Ralph iteration. Working repo is $REPO. Follow PROMPT.md exactly. End by writing $STATUS_FILE." \
    2>>"$LOG_FILE" \
    | tee "$raw_log" \
    | "$FORMATTER" \
    | tee -a "$LOG_FILE"
  pi_rc=${PIPESTATUS[0]}
  set -e
  set -o pipefail

  # Update the convenience symlink so `tail -f .ralph-logs/latest.json` always
  # points at the current iteration.
  ln -sfn "$(basename "$raw_log")" "$RAW_LOG_DIR/latest.json"

  status=$(cat "$STATUS_FILE" 2>/dev/null || echo "missing")

  case "$status" in
    empty)
      echo "ralph: iter $i -> empty (no eligible issues). exiting."
      exit 0
      ;;
    closed:*|failed:*|review:*)
      echo "ralph: iter $i -> $status (pi exit=$pi_rc)"
      unknown_streak=0
      ;;
    missing|*)
      unknown_streak=$((unknown_streak + 1))
      echo "ralph: iter $i -> unexpected status '$status' (pi exit=$pi_rc), streak=$unknown_streak/3"
      if (( unknown_streak >= 3 )); then
        echo "ralph: 3 consecutive unknown statuses, bailing to avoid runaway" >&2
        exit 3
      fi
      ;;
  esac

  sleep 2
done

echo "ralph: hit MAX=$MAX iterations, stopping"
