import hashlib
import json
import subprocess
from pathlib import Path

root = Path('/tmp/labyrinth-perf-2026-09-17')
repo = Path('/Users/borgerding/workspace/Labyrinth.worktrees/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio')

def snapshot():
    return {str(p.relative_to(repo)): hashlib.sha256(p.read_bytes()).hexdigest()
            for directory in ('scripts', 'tests')
            for p in sorted((repo / directory).rglob('*.gd'))}

before = snapshot()
with (root / 'sept18-final4-surface-query-final.log').open('w') as log:
    result = subprocess.run([
        'python3', 'tools/godot_task_runner.py', '--task-id',
        'sept18-final4-surface-query-final', '--stream', '--',
        'godot', '--headless', '--path', '.', '--script',
        'tests/surface_query_handoff_test.gd'], cwd=repo,
        stdout=log, stderr=subprocess.STDOUT)
assert result.returncode == 0, result.returncode
assert before == snapshot(), 'Source changed during call-site proof'
assert 'TEST RESULT: PASS' in (root / 'sept18-final4-surface-query-final.log').read_text()
(root / 'sept18-final4-surface-query-sources.json').write_text(json.dumps({
    'files': before, 'source_invariant': True,
    'check': 'tests/surface_query_handoff_test.gd'}, indent=2) + '\n')
print('Surface call-site proof passed; recursive source guard matched.')
