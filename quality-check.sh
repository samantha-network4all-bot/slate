#!/usr/bin/env bash
# quality-check.sh — Smoke-test the built Notepad app.
#
# Builds (optional), launches the app, waits for it to come up, asks
# the WindowServer how many windows it actually shows, captures a
# screenshot, scans stderr + the system log for crashes, then kills
# the process. Designed for the HITL handoff so a human (or LLM) can
# quickly tell whether a freshly built app is actually usable.
#
# Usage:
#   ./quality-check.sh             # use existing build
#   ./quality-check.sh -b          # build first via ./build-project.sh
#   ./quality-check.sh -c Release  # check Release config (default Debug)
#   ./quality-check.sh -w 5        # wait N seconds after launch (default 3)
#   ./quality-check.sh -k          # keep the app running after the check
#
# Exit codes:
#   0  all checks passed
#   1  build/launch infrastructure failure
#   2  app launched but no window appeared
#   3  app crashed or stderr contained errors
#   4  app failed to launch at all

set -euo pipefail

CONFIG="Debug"
DO_BUILD=0
WAIT_SECS=3
KEEP_RUNNING=0
APP_NAME="Notepad"
BUNDLE_ID="com.bimboware.notepad"
PROCESS_NAME="Notepad"

while getopts ":bc:w:kh" opt; do
  case "$opt" in
    b) DO_BUILD=1 ;;
    c) CONFIG="$OPTARG" ;;
    w) WAIT_SECS="$OPTARG" ;;
    k) KEEP_RUNNING=1 ;;
    h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    \?) echo "Unknown flag -$OPTARG" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")"

APP_PATH="$PWD/build/Build/Products/$CONFIG/$APP_NAME.app"
EXEC_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
ARTIFACTS_DIR="$PWD/.quality-check"
STDERR_LOG="$ARTIFACTS_DIR/stderr.log"
STDOUT_LOG="$ARTIFACTS_DIR/stdout.log"
SCREENSHOT="$ARTIFACTS_DIR/screenshot.png"
REPORT="$ARTIFACTS_DIR/report.md"

mkdir -p "$ARTIFACTS_DIR"
: >"$STDERR_LOG"; : >"$STDOUT_LOG"

# ---------- coloring ----------

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_DIM=$'\033[2m'
else
  C_RESET=""; C_RED=""; C_GRN=""; C_YLW=""; C_DIM=""
fi

pass() { echo "${C_GRN}✓${C_RESET} $1"; }
fail() { echo "${C_RED}✗${C_RESET} $1" >&2; }
warn() { echo "${C_YLW}⚠${C_RESET} $1"; }
info() { echo "${C_DIM}·${C_RESET} $1"; }

# ---------- (optional) build ----------

if (( DO_BUILD == 1 )); then
  info "running ./build-project.sh -c $CONFIG"
  if ! ./build-project.sh -c "$CONFIG" >>"$STDOUT_LOG" 2>&1; then
    fail "build failed — see $STDOUT_LOG"
    exit 1
  fi
  pass "build succeeded"
fi

[[ -d "$APP_PATH" ]] || { fail "app bundle not found at $APP_PATH (run with -b to build)"; exit 1; }
[[ -x "$EXEC_PATH" ]] || { fail "executable missing at $EXEC_PATH"; exit 1; }

# ---------- kill any stale instances ----------

if pgrep -x "$PROCESS_NAME" >/dev/null; then
  info "killing stale $PROCESS_NAME process(es)"
  pkill -x "$PROCESS_NAME" || true
  sleep 1
fi

# ---------- launch ----------

START_TS=$(date +%s)
info "launching $EXEC_PATH"
# Run the executable directly so we capture stderr/stdout. `open -a` would
# detach and silently swallow them.
"$EXEC_PATH" >>"$STDOUT_LOG" 2>>"$STDERR_LOG" &
APP_PID=$!
disown "$APP_PID" 2>/dev/null || true

# Give AppKit a moment to set up
sleep "$WAIT_SECS"

# ---------- liveness check ----------

if ! kill -0 "$APP_PID" 2>/dev/null; then
  fail "process exited before window check (pid $APP_PID)"
  echo ""
  echo "── stderr tail ──"
  tail -40 "$STDERR_LOG" || true
  echo ""
  echo "── stdout tail ──"
  tail -20 "$STDOUT_LOG" || true
  exit 4
fi
pass "process alive (pid $APP_PID)"

# ---------- window count via WindowServer ----------

# Ask the macOS WindowServer how many on-screen windows this process owns.
# We use Quartz's CGWindowListCopyWindowInfo via a tiny swift one-liner
# because `osascript … System Events` requires accessibility permission.
WINDOW_COUNT=$(/usr/bin/swift - <<EOF 2>>"$STDERR_LOG"
import CoreGraphics
import Foundation
let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let info = (CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]]) ?? []
let pid = Int32($APP_PID)
let mine = info.filter { dict in (dict[kCGWindowOwnerPID as String] as? Int32) == pid }
print(mine.count)
EOF
) || WINDOW_COUNT=0
# Strip any whitespace/newlines and default to 0 if non-numeric.
WINDOW_COUNT=$(echo "${WINDOW_COUNT:-0}" | tr -dc '0-9')
WINDOW_COUNT=${WINDOW_COUNT:-0}

if [[ "$WINDOW_COUNT" -gt 0 ]]; then
  pass "$WINDOW_COUNT on-screen window(s) owned by pid $APP_PID"
else
  fail "process is running but has 0 on-screen windows"
fi

# ---------- screenshot (whole screen; reviewer can crop) ----------

if command -v screencapture >/dev/null; then
  screencapture -x "$SCREENSHOT" 2>>"$STDERR_LOG" || true
  if [[ -s "$SCREENSHOT" ]]; then
    pass "screenshot captured: $SCREENSHOT"
  else
    warn "screencapture produced no file"
  fi
fi

# ---------- stderr scan ----------

ERR_HITS=$(grep -cE "fatal error|Fatal Exception|Thread [0-9]+ Crashed|EXC_BAD|signal SIG|NSException" "$STDERR_LOG" 2>/dev/null) || ERR_HITS=0
if [[ "$ERR_HITS" -gt 0 ]]; then
  fail "$ERR_HITS crash-shaped lines in stderr (see $STDERR_LOG)"
else
  pass "no crash signatures in stderr"
fi

# ---------- system log scan (best effort, last 30s) ----------

LOG_HITS=0
if command -v log >/dev/null; then
  LOG_HITS=$(log show --predicate "process == \"$PROCESS_NAME\" AND (messageType == fault OR messageType == error)" \
    --last 30s 2>/dev/null | grep -cE "fault|error") || LOG_HITS=0
  if [[ "$LOG_HITS" -gt 0 ]]; then
    warn "$LOG_HITS error/fault lines in unified log for $PROCESS_NAME"
  else
    info "no fault/error lines in unified log"
  fi
fi

# ---------- write report ----------

ELAPSED=$(( $(date +%s) - START_TS ))
{
  echo "# quality-check report — $(date '+%F %T')"
  echo ""
  echo "- App:         \`$APP_PATH\`"
  echo "- Config:      $CONFIG"
  echo "- PID:         $APP_PID"
  echo "- Window count: **$WINDOW_COUNT**"
  echo "- Stderr crash lines: $ERR_HITS"
  echo "- Unified log fault/error lines: $LOG_HITS"
  echo "- Wall time:   ${ELAPSED}s"
  echo "- Screenshot:  \`$SCREENSHOT\`"
  echo "- Stderr:      \`$STDERR_LOG\`"
  echo "- Stdout:      \`$STDOUT_LOG\`"
  echo ""
  if [[ -s "$STDERR_LOG" ]]; then
    echo "## stderr tail"
    echo ""
    echo '```'
    tail -40 "$STDERR_LOG"
    echo '```'
  fi
} >"$REPORT"

info "report written: $REPORT"

# ---------- cleanup ----------

if (( KEEP_RUNNING == 0 )); then
  if kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$APP_PID" 2>/dev/null || true
  fi
  pass "app terminated"
else
  warn "leaving app running (pid $APP_PID) — kill with: kill $APP_PID"
fi

# ---------- exit code ----------

if [[ "$WINDOW_COUNT" -lt 1 ]]; then
  exit 2
fi
if [[ "$ERR_HITS" -gt 0 ]]; then
  exit 3
fi
exit 0
