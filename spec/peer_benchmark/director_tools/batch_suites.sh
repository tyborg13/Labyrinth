#!/bin/sh
# Full Godot + Python suites on integration HEAD (batch merge verification). Run under codex_unit.py locked.
# usage: [ONLY=godot|python] batch_suites.sh TAG. Python uses the perf-06 parallel runner (4 audited shards).
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
cd /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark || exit 9
TAG=$1; G=0; P=0
echo "=== batch $TAG head $(git rev-parse --short HEAD) $(date +%T)"
if [ "${ONLY:-}" != python ]; then
  python3 tools/godot_task_runner.py --task-id peer-suite --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd > $S/batch_${TAG}_godot.log 2>&1; G=$?
  echo "godot rc=$G"; grep -E "TEST RESULT|FULL SUITE RUNTIME" $S/batch_${TAG}_godot.log | tail -3
fi
if [ "${ONLY:-}" != godot ]; then
  echo "=== python suite $(date +%T)"
  rm -rf $S/pysuite_${TAG}
  LABYRINTH_TASK_ID=peer-suite python3 tools/run_python_suite.py --shards 4 --output-dir $S/pysuite_${TAG} > $S/batch_${TAG}_python.log 2>&1; P=$?
  grep -E "^Ran |^OK|^FAILED|AUDIT FAILED|GUARD" $S/batch_${TAG}_python.log | tail -3
  echo "python rc=$P"
fi
echo "=== done $(date +%T)"
[ $G -eq 0 ] && [ $P -eq 0 ]
