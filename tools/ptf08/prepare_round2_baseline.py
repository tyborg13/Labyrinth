"""Read-only Git snapshots; no Git metadata writes or branch changes."""
from pathlib import Path
import subprocess
import json
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-08/round2-baseline')
BASELINE_REF = 'ee89bc0e4'
OWNED = ('run_scene.gd', 'retained_pass_preview.gd', 'pass_forecast_focus_tooltip.gd', 'turn_order_slots.gd', 'turn_clock_forecast_line.gd', 'turn_clock_forecast_line.gd.uid', 'pass_preview_prewarm.gd')
OUTPUT.mkdir(parents=True, exist_ok=True)
for child in ROOT.iterdir():
    if child.name in ('.git', 'scripts'):
        continue
    target = OUTPUT / child.name
    if not target.exists():
        target.symlink_to(child, target_is_directory=child.is_dir())
(OUTPUT / 'scripts').mkdir(exist_ok=True)
for child in (ROOT / 'scripts').iterdir():
    target = OUTPUT / 'scripts' / child.name
    if child.name not in OWNED and not target.exists():
        target.symlink_to(child, target_is_directory=child.is_dir())
# Include deleted source paths: they are absent from the current directory's
# inventory but required by the old presentation code.
for name in OWNED:
    target = OUTPUT / 'scripts' / name
    if target.is_symlink():
        target.unlink()
    target.write_bytes(subprocess.check_output(['git', 'show', f'{BASELINE_REF}:scripts/{name}'], cwd=ROOT))
(OUTPUT / 'baseline.json').write_text(json.dumps({'ref': subprocess.check_output(['git','rev-parse',BASELINE_REF],cwd=ROOT,text=True).strip(), 'sources': OWNED}, indent=2)+'\n')
print(OUTPUT)
