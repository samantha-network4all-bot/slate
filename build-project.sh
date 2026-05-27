#!/usr/bin/env bash
# build-project.sh — Generate, build, and (optionally) run the Notepad app.
#
# Usage:
#   ./build-project.sh             # generate + build (Debug)
#   ./build-project.sh -c Release  # build in Release config
#   ./build-project.sh -t          # also run XCTest suite
#   ./build-project.sh -o          # open the built .app in Finder/launch it
#   ./build-project.sh -c Release -t -o
#
# Outputs:
#   - Notepad.xcodeproj/                              regenerated via xcodegen
#   - build/Build/Products/<Config>/Notepad.app       compiled application
#   - buildlog.txt                                    full xcodebuild log
#
# Requires:
#   - Xcode (provides xcodebuild) — install via App Store
#   - xcodegen — install via `brew install xcodegen`

set -euo pipefail

PROJECT="Notepad.xcodeproj"
SCHEME="Notepad"
CONFIG="Debug"
RUN_TESTS=0
OPEN_APP=0
DERIVED_DATA="$PWD/build"
LOG_FILE="$PWD/buildlog.txt"

while getopts ":c:toh" opt; do
  case "$opt" in
    c) CONFIG="$OPTARG" ;;
    t) RUN_TESTS=1 ;;
    o) OPEN_APP=1 ;;
    h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    \?) echo "Unknown flag -$OPTARG" >&2; exit 2 ;;
  esac
done

# ---------- preflight ----------

cd "$(dirname "$0")"

command -v xcodebuild >/dev/null \
  || { echo "build-project: 'xcodebuild' not on PATH. Install Xcode from the App Store." >&2; exit 2; }
command -v xcodegen >/dev/null \
  || { echo "build-project: 'xcodegen' not on PATH. Run: brew install xcodegen" >&2; exit 2; }

[[ -f Project.yml ]] \
  || { echo "build-project: Project.yml missing in $PWD" >&2; exit 2; }

# ---------- generate ----------

echo "▶ xcodegen generate"
xcodegen generate --quiet

[[ -d "$PROJECT" ]] \
  || { echo "build-project: $PROJECT not created — check xcodegen output" >&2; exit 2; }

# ---------- build ----------

echo "▶ xcodebuild build ($CONFIG)"
: >"$LOG_FILE"
set +e
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED_DATA" \
  build 2>&1 | tee -a "$LOG_FILE"
build_rc=${PIPESTATUS[0]}
set -e

if (( build_rc != 0 )); then
  echo "✗ build failed (exit $build_rc). Last lines:"
  tail -20 "$LOG_FILE"
  exit "$build_rc"
fi

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/$SCHEME.app"
echo "✓ built: $APP_PATH"

# ---------- test ----------

if (( RUN_TESTS == 1 )); then
  echo "▶ xcodebuild test ($CONFIG)"
  set +e
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    test 2>&1 | tee -a "$LOG_FILE"
  test_rc=${PIPESTATUS[0]}
  set -e
  if (( test_rc != 0 )); then
    echo "✗ tests failed (exit $test_rc)"
    exit "$test_rc"
  fi
  echo "✓ tests passed"
fi

# ---------- run ----------

if (( OPEN_APP == 1 )); then
  if [[ -d "$APP_PATH" ]]; then
    echo "▶ launching $APP_PATH"
    open "$APP_PATH"
  else
    echo "build-project: built app not found at $APP_PATH" >&2
    exit 2
  fi
fi

echo ""
echo "Build complete."
echo "  App:  $APP_PATH"
echo "  Log:  $LOG_FILE"
echo ""
echo "Run it with:  open '$APP_PATH'"
