#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
test -f tools/qa131/live_effects.gd || {
    printf '%s\n' 'Restore the pinned QA-131 harness with git archive 472195358 tools/qa131 | tar -xf -.' >&2
    exit 2
}
out=$(mktemp -d /private/tmp/labyrinth_codex/gfix-34-analytics.XXXXXX)
probe=$(mktemp -d .godot/gfix34-analytics.XXXXXX)
trap 'rm -rf "$probe"' EXIT
cp tools/gfix34/analytics.gd.in "$probe/analytics.gd"
printf 'Analytics evidence: %s\n' "$out"
python3 tools/godot_task_runner.py --task-id gfix-34 --stream -- godot \
    --headless --path . --check-only --script "$probe/analytics.gd"
printf 'PARSE PASS tools/gfix34/analytics.gd.in\n'
LABYRINTH_QA131_LIVE_OUT="$out" python3 tools/godot_task_runner.py --task-id gfix-34 --stream -- godot \
    --headless --fixed-fps 60 --path . --script "$probe/analytics.gd" -- "$@"
