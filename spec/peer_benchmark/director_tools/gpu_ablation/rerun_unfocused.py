"""Rerun only the arms report.py marked 'unfocused sample' (director, 2026-11-06).

Moves each such arm's evidence to native-director/_unfocused_r1/<state>/<arm>, then
reruns its exact planned command serially, then regenerates the tables.
"""
import json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path('/private/tmp/labyrinth_codex/sd-12')
RUN = ROOT / 'native-director'
SOURCE = Path('/Users/borgerding/workspace/Labyrinth.worktrees/sd-12')
summary = json.loads((RUN / 'tables' / 'summary.json').read_text())
targets = {(x['state'], x['arm']) for x in summary['invalid'] if x['issues'] == ['unfocused sample']}
plan = json.loads((ROOT / 'native_commands.json').read_text())
rows = [r for r in plan['arms'] if (r['state'], r['arm']) in targets]
print('SD-12 RERUN: %d arms' % len(rows), flush=True)
for row in rows:
    out = Path(row['output'])
    aside = RUN / '_unfocused_r1' / row['state'] / row['arm']
    aside.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and not aside.exists():
        shutil.move(str(out), str(aside))
    out.mkdir(parents=True, exist_ok=False)
    with (out / 'runner.log').open('w') as log:
        status = subprocess.run(row['command'], cwd=SOURCE, env=dict(os.environ, LABYRINTH_CEL_LOOK='all'), stdout=log, stderr=subprocess.STDOUT).returncode
    print('SD-12 RERUN: %s/%s exit=%d' % (row['state'], row['arm'], status), flush=True)
    if status:
        sys.exit('arm failed: ' + str(out / 'runner.log'))
sys.exit(subprocess.run(['python3', str(ROOT / 'tools' / 'report.py'), '--run-dir', str(RUN)], cwd=SOURCE).returncode)
