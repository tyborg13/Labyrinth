#!/bin/sh
# Merge one approved polish branch whose worktree is already gone; delete the branch afterwards. usage: merge_pol.sh pol-NN "message"
set -u
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
I=/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark
cd $I || exit 9
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "integration dirty"; exit 8; }
git merge --no-ff -m "$2

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" codex/$1 || { echo "MERGE CONFLICT"; exit 7; }
git log --oneline -1 | cut -c1-90
python3 tools/godot_task_runner.py --task-id peer-import --stream -- godot --headless --path . --import > $S/merge_$1_import.log 2>&1; echo import=$?
git status --porcelain --untracked-files=all | grep -E '^\?\? .*\.(import|uid)$' | sed 's/^?? //' | tr '\n' '\0' | xargs -0 git add -- 2>/dev/null
git diff --cached --quiet || { git commit -q -m "Sidecars for the $1 merge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"; git log --oneline -1 | cut -c1-90; }
git status --porcelain --untracked-files=no | head -8 | cut -c1-90
LABYRINTH_TASK_ID=peer-pol python3 tools/run_python_suite.py --shards 4 --output-dir $S/pysuite_$1 > $S/merge_$1_python.log 2>&1; echo python=$?; tail -3 $S/merge_$1_python.log | cut -c1-120
