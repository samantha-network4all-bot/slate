#!/usr/bin/env bash
# ralph-codecheck.sh — Ralph loop that hunts runtime-stability defects
# in the Notepad app and fixes them one at a time, using OpenRouter-hosted
# free models via `pi --print --no-session --mode json`.
#
# Unlike ralph-openrouter.sh (which works the GitHub issue queue), this
# loop reads PROMPT-codecheck.md, which instructs the model to:
#   1. Run ./quality-check.sh -b
#   2. Walk the defect ladder in .claude/skills/codecheck/SKILL.md
#   3. Fix exactly one defect, build green, QA green, commit, push
#
# Usage:
#   ./ralph-codecheck.sh [-s] [MAX_ITERATIONS]
#
# Flags:
#   -s  Interactively pick a free OpenRouter model before starting.
#
# Env:
#   PI_ARGS              extra args passed to `pi` (e.g. "--thinking high")
#   RALPH_MODEL          OpenRouter model override (default openrouter/free)
#   RALPH_ITER_TIMEOUT   seconds per iteration (default 7200)
#
# Stops when:
#   - The model writes `empty` to .ralph-status (no defects left)
#   - Three consecutive iterations return unknown status
#   - MAX_ITERATIONS reached
#
# Successful statuses: empty, fixed:<slug>, failed:<reason>:<slug>

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

readonly MAX="${1:-9999}"
readonly ITER_TIMEOUT="${RALPH_ITER_TIMEOUT:-7200}"
readonly STATUS_FILE=".ralph-status"
readonly PROMPT_FILE="PROMPT-codecheck.md"
readonly LOG_FILE="buildlog-codecheck.log"
readonly RAW_LOG_DIR=".ralph-logs"
readonly FORMATTER="./ralph-format.sh"

DEFAULT_MODEL="${RALPH_MODEL:-openrouter/free}"

# ---------- free model picker (-s) ----------

pick_free_model() {
  echo "ralph-codecheck: fetching free OpenRouter models..." >&2
  local json
  json=$(curl -fsS https://openrouter.ai/api/v1/models) || {
    echo "ralph-codecheck: failed to fetch OpenRouter model list" >&2
    return 1
  }

  local -a ids ctxs
  while IFS=$'\t' read -r id _name ctx; do
    ids+=("$id"); ctxs+=("$ctx")
  done < <(echo "$json" | jq -r '
    .data
    | map(select((.pricing.prompt == "0") and (.pricing.completion == "0")))
    | sort_by(-(.context_length // 0))
    | .[] | [.id, .name, (.context_length // 0)] | @tsv')

  local count=${#ids[@]}
  if (( count == 0 )); then
    echo "ralph-codecheck: no free models returned" >&2; return 1
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
    echo "ralph-codecheck: invalid selection '$choice'" >&2
  done

  DEFAULT_MODEL="${ids[$((choice - 1))]}"
  echo "ralph-codecheck: using model $DEFAULT_MODEL" >&2
}

if (( SELECT_MODEL == 1 )); then
  pick_free_model || exit 2
fi

# ---------- preflight ----------

cd "$(dirname "$0")"

[[ -f "$PROMPT_FILE" ]] || { echo "ralph-codecheck: $PROMPT_FILE missing in $(pwd)" >&2; exit 2; }
[[ -f .claude/skills/codecheck/SKILL.md ]] \
  || { echo "ralph-codecheck: .claude/skills/codecheck/SKILL.md missing" >&2; exit 2; }
[[ -x ./quality-check.sh ]] \
  || { echo "ralph-codecheck: ./quality-check.sh missing or not executable" >&2; exit 2; }
[[ -x ./build-project.sh ]] \
  || { echo "ralph-codecheck: ./build-project.sh missing or not executable" >&2; exit 2; }

command -v pi >/dev/null   || { echo "ralph-codecheck: 'pi' not on PATH" >&2; exit 2; }
command -v git >/dev/null  || { echo "ralph-codecheck: 'git' not on PATH" >&2; exit 2; }
command -v jq >/dev/null   || { echo "ralph-codecheck: 'jq' not on PATH (brew install jq)" >&2; exit 2; }
command -v curl >/dev/null || { echo "ralph-codecheck: 'curl' not on PATH" >&2; exit 2; }
[[ -x "$FORMATTER" ]]      || { echo "ralph-codecheck: $FORMATTER not executable" >&2; exit 2; }
mkdir -p "$RAW_LOG_DIR"

if command -v timeout >/dev/null; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null; then
  TIMEOUT_BIN=gtimeout
else
  echo "ralph-codecheck: install GNU timeout (brew install coreutils)" >&2; exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ralph-codecheck: not in a git repo" >&2; exit 2
fi

# ---------- loop ----------

read -r -a PI_ARGS_ARR <<<"${PI_ARGS:-}"

unknown_streak=0

for ((i = 1; i <= MAX; i++)); do
  ts="$(date +%Y%m%d-%H%M%S)"
  raw_log="$RAW_LOG_DIR/codecheck-${i}-${ts}.json"

  banner="── codecheck iter $i / $MAX · $(date '+%F %T') · model=$DEFAULT_MODEL · timeout=${ITER_TIMEOUT}s ──"
  echo "$banner"
  echo "$banner" >> "$LOG_FILE"

  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "ralph-codecheck: PROMPT-codecheck.md disappeared, bailing" >&2
    exit 4
  fi
  prompt_lines=$(wc -l <"$PROMPT_FILE" | tr -d ' ')
  prompt_head=$(head -n 1 "$PROMPT_FILE")
  echo "ralph-codecheck: prompt ok ($prompt_lines lines) — first line: $prompt_head" \
    | tee -a "$LOG_FILE"

  # Refuse to start if working tree is dirty — a stale half-edit from a
  # previous crashed iteration would corrupt the next one's diff.
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "ralph-codecheck: working tree dirty before iter $i — refusing to start" >&2
    git status --short >&2
    exit 5
  fi

  rm -f "$STATUS_FILE"

  set +o pipefail
  set +e
  "$TIMEOUT_BIN" "$ITER_TIMEOUT" pi --print --no-session --mode json \
    --provider openrouter --model "$DEFAULT_MODEL" \
    --append-system-prompt "$PROMPT_FILE" \
    --tools read,bash,edit,write,grep,find,ls \
    ${PI_ARGS_ARR[@]+"${PI_ARGS_ARR[@]}"} \
    "Run one codecheck iteration. Follow PROMPT-codecheck.md and the codecheck skill exactly. End by writing $STATUS_FILE." \
    2>>"$LOG_FILE" \
    | tee "$raw_log" \
    | "$FORMATTER" \
    | tee -a "$LOG_FILE"
  pi_rc=${PIPESTATUS[0]}
  set -e
  set -o pipefail

  ln -sfn "$(basename "$raw_log")" "$RAW_LOG_DIR/latest.json"

  # Detect LLM connection failures up front so a dead endpoint doesn't
  # masquerade as "missing" for 3 iterations.
  if [[ -s "$raw_log" ]] \
     && ! grep -q '"stopReason":"end_turn"\|"stopReason": "end_turn"\|"stopReason":"tool_use"\|"stopReason": "tool_use"' "$raw_log" \
     && grep -q '"errorMessage"' "$raw_log"; then
    err_msg=$(grep -o '"errorMessage":"[^"]*"' "$raw_log" | head -n 1 | sed 's/.*":"//;s/"$//')
    echo "ralph-codecheck: iter $i -> LLM unreachable (${err_msg:-unknown}), bailing" >&2
    exit 6
  fi

  status=$(cat "$STATUS_FILE" 2>/dev/null || echo "missing")

  case "$status" in
    empty)
      echo "ralph-codecheck: iter $i -> empty (no defects found). exiting."
      exit 0
      ;;
    fixed:*|failed:*)
      echo "ralph-codecheck: iter $i -> $status (pi exit=$pi_rc)"
      unknown_streak=0
      ;;
    missing|*)
      unknown_streak=$((unknown_streak + 1))
      echo "ralph-codecheck: iter $i -> unexpected status '$status' (pi exit=$pi_rc), streak=$unknown_streak/3"
      if (( unknown_streak >= 3 )); then
        echo "ralph-codecheck: 3 consecutive unknown statuses, bailing" >&2
        exit 3
      fi
      ;;
  esac

  sleep 2
done

echo "ralph-codecheck: hit MAX=$MAX iterations, stopping"
