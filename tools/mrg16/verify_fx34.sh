#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${MRG16_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/mrg-16}
baseline=${MRG16_FX34_BASELINE:-/private/tmp/labyrinth_codex/fx-34/headless/before}
stage=$(mktemp -d .godot/mrg16-fx34.XXXXXX)
trap 'rm -rf "$stage"' EXIT
export PYTHONDONTWRITEBYTECODE=1

# Stage only the original beat instrumentation. Gear reads live prop commands.
mkdir "$stage/current"
python3 - "$stage/current" <<'PY'
from pathlib import Path
import sys

sys.path.insert(0, "tools/fx34")
import stage

stage.stage(Path(sys.argv[1]).resolve(), before=False, instrument=False)
chain = Path(sys.argv[1]) / "scripts/chain_attack_feedback.gd"
source = chain.read_text()
marker = '\t\tawait host.call("_play_timed_animation_frames", frame_count,'
assert source.count(marker) == 1
beat = f'\t\t{stage.AUDIT}.beat(index, frame_count, frame_seconds, contact)\n'
chain.write_text(source.replace(marker, beat + marker))
PY

python3 tools/godot_task_runner.py --task-id mrg-16 --stream -- godot --headless --fixed-fps 60 \
    --path "$stage/current" --script tools/mrg16/verify_fx34.gd -- --out "$out/fx34-verify" \
    --compare-before "$baseline" "$@"
