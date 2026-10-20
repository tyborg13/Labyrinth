#!/bin/sh
set -u
UNIT=$1
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
cd /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark || exit 9
echo "=== import $(date +%T)"
python3 tools/godot_task_runner.py --task-id peer-import --stream -- godot --headless --path . --import > $S/merge_${UNIT}_import.log 2>&1; echo import=$?
N=$(git status --porcelain --untracked-files=all | grep -E '^\?\? .*\.(import|uid)$' | wc -l | tr -d ' ')
OTHER=$(git status --porcelain --untracked-files=all | grep -v -E '\.(import|uid)$' | grep -v '^?? output/' | wc -l | tr -d ' ')
echo "new sidecars=$N other_changes=$OTHER"
git status --porcelain --untracked-files=all | grep -v -E '\.(import|uid)$' | grep -v '^?? output/' | head -20
if [ "$N" != "0" ]; then
  git status --porcelain --untracked-files=all | grep -E '^\?\? .*\.(import|uid)$' | sed 's/^?? //' | tr '\n' '\0' | xargs -0 git add --
  git commit -q -m "Sidecars for the $UNIT merge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git log --oneline -1
fi
echo "=== godot suite $(date +%T)"
python3 tools/godot_task_runner.py --task-id peer-suite --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd > $S/merge_${UNIT}_godot.log 2>&1; G=$?
echo "godot rc=$G"; grep -E "TEST RESULT|FAIL" $S/merge_${UNIT}_godot.log | tail -8
echo "=== python suite $(date +%T)"
python3 -m unittest discover -s tests -p 'test_*.py' > $S/merge_${UNIT}_python.log 2>&1; P=$?
tail -4 $S/merge_${UNIT}_python.log
echo "python rc=$P"
echo "=== done $(date +%T) head $(git rev-parse --short HEAD)"
[ $G -eq 0 ] && [ $P -eq 0 ]
