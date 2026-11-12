"""Run rd-06 proof against the exact brief base without touching Git metadata."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = '14a369b61'
path = ROOT / 'tools/rd06/_baseline_board.gd'
try:
    source = subprocess.check_output(['git', 'show', f'{BASE}:scripts/combat_board_view.gd'], cwd=ROOT, text=True)
    path.write_text('\n'.join(line for line in source.splitlines() if not line.startswith('class_name ')) + '\n')
    Path(str(path) + '.uid').write_text('uid://c2rd06baseline\n')
    print(f'RD06 BASE: {BASE}', flush=True)
    result = subprocess.run(sys.argv[1:], cwd=ROOT, env={**os.environ, 'RD06_BASELINE': '1'})
finally:
    path.unlink(missing_ok=True)
    Path(str(path) + '.uid').unlink(missing_ok=True)
raise SystemExit(result.returncode)
