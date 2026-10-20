#!/bin/sh
# Drain watchdog events: keep going while events are FINISHED image jobs listed in $SKIP (space-separated prefixes
# already reviewed); exit and print on anything else.
while true; do
  out=$(python3 "$HOME/.claude/skills/orchestrate-codex/scripts/codex_unit.py" watch 2>&1)
  echo "$out"
  line=$(echo "$out" | grep -E "^(FINISHED|DIED|KILLED|NOSTART|STALLED|HEARTBEAT|IDLE)" | head -1)
  case "$line" in
    FINISHED\ img-*) continue ;;
    *) exit 0 ;;
  esac
done
