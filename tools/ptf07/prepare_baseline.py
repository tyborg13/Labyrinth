"""Build a read-only HEAD forecast adapter for matched runtime measurements."""
import json
from pathlib import Path
import subprocess

OUTPUT_DIR = Path('/private/tmp/labyrinth_codex/ptf-07')
BASELINE_REF = '7cf181c7e26428b39d3350b52b2586ac89f2bf94'
FUNCTIONS = ('begin_revealed_enemy_actions_preview', 'advance_revealed_enemy_actions_preview',
             'revealed_enemy_actions_preview_result')
source = subprocess.check_output(['git', 'show', BASELINE_REF + ':scripts/combat_engine.gd'], text=True)
head = subprocess.check_output(['git', 'rev-parse', BASELINE_REF], text=True).strip()
adapter = ['extends "res://scripts/combat_engine.gd"\n',
           'var _baseline_guard_engine := preload("res://scripts/combat_engine.gd").new()\n']
for name in FUNCTIONS:
    start = source.index('func ' + name + '(')
    end = source.find('\nfunc ', start + 1)
    body = source[start:end if end >= 0 else len(source)]
    # The production optimization requires the exact production Script path.
    # Delegate only this identity check to a real engine; keep its actual cost.
    body = body.replace('can_defer_unrevealed_selection(self, state)',
                        'can_defer_unrevealed_selection(_baseline_guard_engine, state)')
    adapter.append(body + '\n')
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
(OUTPUT_DIR / 'baseline_preview.gd').write_text('\n'.join(adapter))
(OUTPUT_DIR / 'baseline.json').write_text(json.dumps({'head': head, 'functions': FUNCTIONS}, indent=2) + '\n')
print('PTF07 BASELINE: ' + head)
