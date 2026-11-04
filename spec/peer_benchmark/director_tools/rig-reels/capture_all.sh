#!/bin/sh
# Windowed reel captures, one after another, each under the director lock (each run re-checks the owner first).
cd "$(dirname "$0")/.."
for spec in "rr-52 last_lamplighter" "rr-56 storm_cantor" "peer-benchmark ashen_reaver"; do
  set -- $spec
  [ -n "$ONLY" ] && [ "$ONLY" != "$2" ] && continue
  echo "=== $2 $(date +%T)"
  python3 ~/.claude/skills/orchestrate-codex/scripts/codex_unit.py locked -- python3 tools/rig_reel.py /Users/borgerding/workspace/Labyrinth.worktrees/$1 work/$2 work/$2_plan.json -- --scenario guardian --guardian-id $2 --guardian-case encounter --seed 83 > work/$2_run.log 2>&1
  echo "=== $2 exit $? $(date +%T)"; tail -3 work/$2_run.log
  grep -q "BLOCKED" work/$2_run.log && exit 3
done
echo ALL_DONE
