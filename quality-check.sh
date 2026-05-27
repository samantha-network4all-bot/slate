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
#   ./quality-check.sh             # basic smoke (window + crash scan)
#   ./quality-check.sh -b          # build first via ./build-project.sh
#   ./quality-check.sh -c Release  # check Release config (default Debug)
#   ./quality-check.sh -w 5        # wait N seconds after launch (default 3)
#   ./quality-check.sh -i          # also run interactive rungs (typing + ⌘O)
#   ./quality-check.sh -k          # keep the app running after the check
#
# Exit codes:
#   0  all checks passed
#   1  build/launch infrastructure failure
#   2  app launched but no window appeared
#   3  app crashed or stderr contained errors
#   4  app failed to launch at all
#   5  -i: typing produced no characters in the focused text view
#   6  -i: app crashed during File→Open (⌘O) probe
#
# Interactive mode (-i) requires Terminal (or whatever runs this script)
# to have macOS Accessibility permission:
#   System Settings → Privacy & Security → Accessibility → enable Terminal
# Without it, the rungs are skipped with a warning rather than failing.

set -euo pipefail

CONFIG="Debug"
DO_BUILD=0
WAIT_SECS=3
KEEP_RUNNING=0
INTERACTIVE=0
APP_NAME="Notepad"
BUNDLE_ID="com.bimboware.notepad"
PROCESS_NAME="Notepad"

while getopts ":bc:w:kih" opt; do
  case "$opt" in
    b) DO_BUILD=1 ;;
    c) CONFIG="$OPTARG" ;;
    w) WAIT_SECS="$OPTARG" ;;
    k) KEEP_RUNNING=1 ;;
    i) INTERACTIVE=1 ;;
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

# ---------- interactive rungs (-i) ----------

TYPING_RESULT="skipped"
OPEN_RESULT="skipped"

if (( INTERACTIVE == 1 )); then
  info "interactive mode — bringing $APP_NAME to front"

  # Bring the app to front so synthetic input reaches it (not some other app).
  osascript -e "tell application id \"$BUNDLE_ID\" to activate" 2>>"$STDERR_LOG" || true
  sleep 1

  # --- rung: typing ---
  # Strategy: post a known string via CGEvent, then read the AXValue of the
  # process's AXFocusedUIElement back. If accessibility isn't granted to the
  # terminal, the readback returns "" and we report "skipped" instead of failing.

  TEST_STRING="qcheck-$(date +%s)"
  info "typing test: posting '$TEST_STRING' as keystrokes"

  /usr/bin/swift - "$TEST_STRING" "$APP_PID" >>"$STDOUT_LOG" 2>>"$STDERR_LOG" <<'SWIFT'
import ApplicationServices
import AppKit

let text = CommandLine.arguments[1]
let pid = pid_t(CommandLine.arguments[2]) ?? 0

// Post each character via CGEvent keyboard down/up using unicode strings —
// avoids having to map to virtual keycodes.
for scalar in text.unicodeScalars {
    var unichar = UInt16(scalar.value)
    if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
        down.postToPid(pid)
    }
    if let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
        up.postToPid(pid)
    }
    usleep(20_000) // 20ms between events
}
SWIFT

  sleep 1

  # Read back the focused element's AXValue via AX API.
  READ_BACK=$(/usr/bin/swift - "$APP_PID" 2>>"$STDERR_LOG" <<'SWIFT' || true
import ApplicationServices
let pid = pid_t(CommandLine.arguments[1]) ?? 0
guard pid > 0 else { print(""); exit(0) }

let app = AXUIElementCreateApplication(pid)
var focused: AnyObject?
let err = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused)
guard err == .success, let element = focused else {
    // .apiDisabled (-25211) = accessibility not granted; surface a token so caller can skip
    if err.rawValue == -25211 { print("__AX_DISABLED__") }
    exit(0)
}
var value: AnyObject?
let vErr = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value)
if vErr == .success, let s = value as? String {
    print(s)
}
SWIFT
)

  if [[ "$READ_BACK" == "__AX_DISABLED__" ]]; then
    warn "typing rung skipped — grant Accessibility to Terminal in System Settings"
    TYPING_RESULT="skipped-no-ax"
  elif [[ -z "$READ_BACK" ]]; then
    warn "typing rung: could not read focused element value (no focus? not a text field?)"
    TYPING_RESULT="skipped-no-readback"
  elif [[ "$READ_BACK" == *"$TEST_STRING"* ]]; then
    pass "typing works — focused element contains '$TEST_STRING'"
    TYPING_RESULT="pass"
  else
    fail "typing FAILED — focused element value: $(echo "$READ_BACK" | head -c 200)"
    TYPING_RESULT="fail"
  fi

  # --- rung: File→Open via ⌘O ---
  if kill -0 "$APP_PID" 2>/dev/null; then
    info "menu probe: posting ⌘O to $APP_NAME"
    osascript -e "tell application \"System Events\" to keystroke \"o\" using {command down}" 2>>"$STDERR_LOG" || true
    sleep 2
    if kill -0 "$APP_PID" 2>/dev/null; then
      pass "process alive after ⌘O (no crash)"
      OPEN_RESULT="pass"
      # Best effort: dismiss any sheet/dialog that opened so we don't wedge the app.
      osascript -e 'tell application "System Events" to key code 53' 2>/dev/null || true # ESC
      sleep 1
    else
      fail "process CRASHED after ⌘O (File→Open is broken)"
      OPEN_RESULT="fail"
    fi
  else
    fail "process died before File→Open probe"
    OPEN_RESULT="fail"
  fi

  # Re-capture screenshot after interactive rungs
  if command -v screencapture >/dev/null; then
    screencapture -x "$ARTIFACTS_DIR/screenshot-after.png" 2>>"$STDERR_LOG" || true
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
  echo "- Typing rung: **$TYPING_RESULT**"
  echo "- File→Open (⌘O) rung: **$OPEN_RESULT**"
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
if [[ "$OPEN_RESULT" == "fail" ]]; then
  exit 6
fi
if [[ "$TYPING_RESULT" == "fail" ]]; then
  exit 5
fi
exit 0
