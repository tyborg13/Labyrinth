#!/bin/sh
# Merge spx-04 and the squashed rr-31, re-measure the revision-6 baseline on the result (orders now change Warband
# fights; the bot file changed too), commit it, then run both full suites once. Run under codex_unit.py locked.
set -u
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
I=/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark
cd $I || exit 9
git checkout -- experiments/cutouts/briar_weaver/mq9/proof/samples.json
SKIP_SUITES=1 sh $S/merge_unit.sh spx-04 "Merge codex/spx-04: the six Warband orders (Thornwall, Barrage, held wind, ice wall, Dynamo threshold, Prior's veil), each telegraphed (Codex SIGNOFF a8498874f)" || exit $?
WT=/Users/borgerding/workspace/Labyrinth.worktrees/rr-31 BRANCH=codex/rr-31-squash SKIP_SUITES=1 sh $S/merge_unit.sh rr-31 "Merge Slag Mortar v2 (rr-30 + rr-31, squashed): arms stay attached in every action (Codex SIGNOFF e9aadfc32)" || exit $?
cd $I
echo "=== baseline $(date +%T)"
python3 tools/encounter_bot.py --baseline --revision 6 --seed 1 --runs 200 --workers 6 > $S/baseline_r6.log 2>&1; B=$?
tail -3 $S/baseline_r6.log; echo "baseline rc=$B"
[ $B -eq 0 ] || exit 10
git status --porcelain --untracked-files=all | grep -v '^?? output/'
OUT=$(git status --porcelain --untracked-files=all | grep -v '^?? output/' | grep -v ' spec/peer_benchmark/encounter_redesign/' | wc -l | tr -d ' ')
[ "$OUT" = 0 ] || { echo "baseline touched files outside the measurement dir"; exit 11; }
git add spec/peer_benchmark/encounter_redesign
git commit -q -m "Re-measure the revision-6 bot baseline with the Warband orders and the current bot (200 seeds per tier/cohort)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git log --oneline -1
echo "=== godot suite $(date +%T)"
python3 tools/godot_task_runner.py --task-id peer-suite --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd > $S/merge_chain_godot.log 2>&1; G=$?
echo "godot rc=$G"; grep -E "TEST RESULT|FAIL" $S/merge_chain_godot.log | tail -8
echo "=== python suite $(date +%T)"
python3 -m unittest discover -s tests -p 'test_*.py' > $S/merge_chain_python.log 2>&1; P=$?
tail -4 $S/merge_chain_python.log; echo "python rc=$P"
git checkout -- experiments/cutouts/briar_weaver/mq9/proof/samples.json 2>/dev/null
echo "=== done $(date +%T) head $(git rev-parse --short HEAD)"
[ $G -eq 0 ] && [ $P -eq 0 ]
