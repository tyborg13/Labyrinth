import subprocess,json,hashlib
from pathlib import Path
root=Path('/tmp/labyrinth-perf-2026-09-17')
repo=Path('/Users/borgerding/workspace/Labyrinth.worktrees/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio')
files=lambda:{str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for d in ('scripts','tests') for p in sorted((repo/d).rglob('*.gd'))}
before=files()
for name,script in [('geometry','elemental_spell_geometry_equivalence_probe'),('draw-flow','card_draw_hand_flow_probe'),('hand','locked_hand_cache_lifecycle_probe')]:
 print('START',name,flush=True)
 with (root/('sept18-final4-'+name+'.log')).open('w') as f:
  result=subprocess.run(['python3','tools/visual_probe_runner.py','tests/'+script+'.gd','--task-id','sept18-final4-'+name,'--no-headless','--display-driver','macos','--audio-driver','Dummy','--timeout','300','--min-images','1','--expect-size','1920x1080'],cwd=repo,stdout=f,stderr=subprocess.STDOUT)
 print('DONE',name,result.returncode,flush=True)
 assert result.returncode==0
assert before==files()
(root/'sept18-final4-visual-sources.json').write_text(json.dumps({'files':before,'source_invariant':True},indent=2)+'\n')
