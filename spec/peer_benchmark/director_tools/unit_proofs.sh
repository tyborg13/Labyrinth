#!/bin/sh
# usage: unit_proofs.sh UNIT SCRIPT STAGE...
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
U=$1; P=$2; shift 2
cd /Users/borgerding/workspace/Labyrinth.worktrees/$U || exit 9
if python3 /Users/borgerding/.claude/skills/orchestrate-codex/scripts/codex_unit.py status 2>/dev/null | grep -E "^$U " | grep -q running; then
  echo "DEFERRED: $U has a Codex round running; re-queue after it finishes"; exit 3
fi
for stage in "$@"; do
  echo "=== $U $stage $(date +%T)"
  sh $P $stage > $S/${U}_$stage.log 2>&1
  echo "$U $stage rc=$?"; grep -E "PASS|FAIL|hole|detached|moved|Error" $S/${U}_$stage.log | tail -3
done
echo "=== done $(date +%T)"
