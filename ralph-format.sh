#!/usr/bin/env bash
# ralph-format.sh — turns pi's `--mode json` event firehose into a
# human-readable one-line-per-event progress stream.
#
# Usage:  pi --mode json ... | ralph-format.sh

set -euo pipefail

exec jq -rc --unbuffered '
  def short(s; n):
    (s | tostring) | gsub("\n"; " ") | gsub("\\s+"; " ")
    | if length > n then .[:n] + "…" else . end;

  if .type == "session" then
    "── session " + ((.id // "?")[0:8]) + " · cwd=" + (.cwd // "?")

  elif .type == "agent_start" then
    "── agent start ──"

  elif .type == "turn_start" then
    "── turn ──"

  # User-role message_end carries either the seed prompt or tool results.
  elif .type == "message_end" and .message.role == "user" then
    [ .message.content[]?
      | if   .type == "tool_result" then "  ← result: " + short((.content // "" | tostring); 200)
        elif .type == "text"        then "▶ user:   " + short(.text; 200)
        else empty end
    ] | .[]

  # Assistant-role message_end carries the assembled think/tool/text blocks.
  elif .type == "message_end" and .message.role == "assistant" then
    [ .message.content[]?
      | if   .type == "thinking" then "  · think: " + short(.thinking; 160)
        elif .type == "toolCall" then "→ " + .name + "(" + short(.arguments; 140) + ")"
        elif .type == "text"     then "  ← say:   " + short(.text; 240)
        else empty end
    ] | .[]

  else empty
  end
' 2>/dev/null || true
