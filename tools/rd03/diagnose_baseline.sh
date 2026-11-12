#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
paths = []
try:
    print('RD03 BASELINE HEAD:', subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), flush=True)
    for name in ['combat_board_view', 'run_scene']:
        text = subprocess.check_output(['git', 'show', 'HEAD:scripts/' + name + '.gd'], text=True)
        path = Path('tools/rd03/_baseline_' + name + '.gd')
        paths.extend([path, Path(str(path) + '.uid')])
        path.write_text('\n'.join(line for line in text.splitlines() if not line.startswith('class_name ')) + '\n')
    result = subprocess.run(['python3', 'tools/godot_task_runner.py', '--task-id', 'rd-03', '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tools/rd03/diagnostics.gd'], env={**os.environ, 'RD03_BASELINE': '1'})
finally:
    for path in paths:
        if path.exists(): path.unlink()
raise SystemExit(result.returncode)
PY
