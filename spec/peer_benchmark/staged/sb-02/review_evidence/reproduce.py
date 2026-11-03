"""Run a saved review experiment from the reviewed disposable checkout."""
from pathlib import Path
import subprocess,sys
artifact=Path(__file__).resolve().parent
name=sys.argv[1] if len(sys.argv)>1 else 'live_hand'
if name not in ('live_hand','live_geometry','geometry','movement'):
 raise SystemExit('Expected live_hand, live_geometry, geometry or movement')
p=Path('tests/_sb01_review_reproduction.gd')
if p.exists():raise SystemExit('Refusing to overwrite '+str(p))
try:
 p.write_bytes((artifact/(name+'.gd')).read_bytes())
 result=subprocess.run(['python3','tools/godot_task_runner.py','--task-id','sb-01-review','--stream','--','godot','--headless','--path','.','--script',str(p)])
finally:p.unlink()
raise SystemExit(result.returncode)
