#!/bin/sh
# Merge an invisible (or owner-approved) unit into integration, run the Python default group, fast-forward release,
# then remove the unit's worktree and branch. Stops on a merge conflict. Run under codex_unit.py locked.
# usage: merge_invisible.sh UNIT "merge message"
set -u
U=$1; MSG=$2
M=/Users/borgerding/workspace/Labyrinth
I=$M.worktrees/peer-benchmark
R=$M.worktrees/release
cd $M || exit 9
WT=/nonexistent SKIP_SUITES=1 sh spec/peer_benchmark/director_tools/merge_unit.sh $U "$MSG" > /private/tmp/labyrinth_codex/merge_$U.log 2>&1
rc=$?; grep -E "^=== merge|CONFLICT|import=|sidecars|dirty" /private/tmp/labyrinth_codex/merge_$U.log
[ $rc -eq 0 ] || { echo "MERGE FAILED rc=$rc (integration may be mid-merge)"; exit $rc; }
cd $I && LABYRINTH_TASK_ID=peer-suite python3 tools/run_python_suite.py > /private/tmp/labyrinth_codex/merge_${U}_python.log 2>&1
p=$?; echo "python default rc=$p"; [ $p -eq 0 ] || exit $p
cd $R && git merge --ff-only -q codex/peer-benchmark && git log --oneline -1
cd $M && git merge-base --is-ancestor codex/$U codex/release && { git worktree remove --force $M.worktrees/$U 2>/dev/null; git branch -D codex/$U; }
exit 0
