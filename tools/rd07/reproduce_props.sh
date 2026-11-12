#!/bin/sh
set -eu
# Read-only Git access; the baseline board exists only for this reproduction.
trap 'rm -f tools/rd07/baseline_board.gd' EXIT
python3 - <<'PY'
from pathlib import Path
import subprocess
source = subprocess.check_output(['git', 'show', 'HEAD:scripts/combat_board_view.gd'], text=True)
Path('tools/rd07/baseline_board.gd').write_text(source.replace('class_name CombatBoardView', ''))
PY
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/reproduce_props.gd
