#!/usr/bin/env bash
# ralph-format.sh — turns pi's `--mode json` event firehose into a
# human-readable, color-coded, icon-prefixed progress stream.
#
# Usage:  pi --mode json ... | ralph-format.sh
#
# Env:
#   NO_COLOR=1   disable ANSI colors (per https://no-color.org)

set -euo pipefail

if [[ -n "${NO_COLOR:-}" ]]; then
  C_RESET=""; C_DIM=""; C_BOLD=""
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_GRAY=""
else
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
  C_GRAY=$'\033[90m'
fi

exec jq -rc --unbuffered \
  --arg R "$C_RESET" \
  --arg D "$C_DIM" \
  --arg B "$C_BOLD" \
  --arg RED "$C_RED" \
  --arg GRN "$C_GREEN" \
  --arg YLW "$C_YELLOW" \
  --arg BLU "$C_BLUE" \
  --arg MAG "$C_MAGENTA" \
  --arg CYN "$C_CYAN" \
  --arg GRY "$C_GRAY" '
  def short(s; n):
    (s | tostring) | gsub("\n"; " ") | gsub("\\s+"; " ")
    | if length > n then .[:n] + "…" else . end;

  # Multi-line preserving truncation: keeps newlines so long tool results
  # (file contents, command output) stay readable.
  def block(s; n):
    (s | tostring)
    | if length > n then .[:n] + "\n  " + $D + "…(" + ((length - n) | tostring) + " more chars)" + $R else . end;

  def indent(s; prefix):
    (s | tostring) | split("\n") | map(prefix + .) | join("\n");

  # Heuristic: did this tool_result look like an error? pi does not flag
  # tool_result.is_error in --mode json output, so we sniff common signals.
  def looks_like_error(s):
    (s | tostring | ascii_downcase) as $t
    | ($t | test("(^|\\W)(error|traceback|exception|failed|fatal|cannot|not found|no such)(\\W|$)"));

  if .type == "session" then
    $CYN + "── session " + ((.id // "?")[0:8]) + " · cwd=" + (.cwd // "?") + $R

  elif .type == "agent_start" then
    $CYN + "── agent start ──" + $R

  elif .type == "agent_end" then
    ( [ .messages[]? | select(.role == "assistant") ] | last ) as $last
    | ($GRY + "── agent end" +
        (if $last.stopReason   then " (" + $last.stopReason + ")" else "" end) +
        (if $last.errorMessage then " " + $RED + $last.errorMessage + $GRY else "" end) +
        (if .willRetry == true then " " + $YLW + "[will retry]" + $GRY else "" end) +
        " ──" + $R)

  elif .type == "turn_start" then
    $CYN + "── turn ──" + $R

  elif .type == "auto_retry_start" then
    $YLW + "⟳ auto-retry" + $R

  # User-role message_end carries either the seed prompt or tool results.
  elif .type == "message_end" and .message.role == "user" then
    [ .message.content[]?
      | if   .type == "tool_result" then
          (.content // "" | tostring) as $body
          | (if looks_like_error($body) then $RED + "  ✗ result:" + $R else $GRN + "  ✓ result:" + $R end)
            + "\n" + indent(block($body; 1200); $D + "    │ " + $R)
        elif .type == "text" then
          $BLU + $B + "▶ user:" + $R + " " + short(.text; 400)
        else empty end
    ] | .[]

  # Assistant-role message_end carries the assembled think/tool/text blocks.
  elif .type == "message_end" and .message.role == "assistant" then
    [ .message.content[]?
      | if   .type == "thinking" then
          $MAG + "  ✻ think:" + $R + " " + $D + short(.thinking; 500) + $R
        elif .type == "toolCall" then
          $YLW + "→ " + (.name // "?") + $R + " " + $D + "(" + short(.arguments; 400) + ")" + $R
        elif .type == "text" then
          $GRN + "  ● say:" + $R + " " + short(.text; 600)
        else empty end
    ] | .[]

  else empty
  end
' 2>/dev/null || true
