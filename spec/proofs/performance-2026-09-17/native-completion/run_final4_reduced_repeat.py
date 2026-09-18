import os,subprocess,json,hashlib,time
from pathlib import Path
root=Path('/tmp/labyrinth-perf-2026-09-17')
repos={'candidate':Path('/Users/borgerding/workspace/Labyrinth.worktrees/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio'),'base':root/'tracker-baseline'}
common={'LABYRINTH_RUNTIME_PERF_CAPPED_HAND':'1'}
focused={**common,'LABYRINTH_RUNTIME_PERF_SECTIONS':'0','LABYRINTH_RUNTIME_PERF_FOCUSED':'1','LABYRINTH_RUNTIME_PERF_FOCUSED_ACTIONS':'1','LABYRINTH_RUNTIME_PERF_CARD_FILTER':'gust_step,shadow_step,wildfire_halo','LABYRINTH_RUNTIME_PERF_ABILITY_FILTER':'quick_wits,encore,prismatic_instinct'}
items=[('full-base','base','runtime_frame',common),('full-candidate','candidate','runtime_frame',common),('tail-candidate-a','candidate','runtime_frame',focused),('tail-base-a','base','runtime_frame',focused),('tail-base-b','base','runtime_frame',focused),('tail-candidate-b','candidate','runtime_frame',focused),('reduced-base','base','runtime_frame',{**focused,'LABYRINTH_RUNTIME_PERF_REDUCED_MOTION':'1'}),('reduced-candidate','candidate','runtime_frame',{**focused,'LABYRINTH_RUNTIME_PERF_REDUCED_MOTION':'1'}),('early-candidate','candidate','representative_combat',{'LABYRINTH_COMBAT_PROFILE':'early','LABYRINTH_RUNTIME_PERF_SECTIONS':'0'}),('early-base','base','representative_combat',{'LABYRINTH_COMBAT_PROFILE':'early','LABYRINTH_RUNTIME_PERF_SECTIONS':'0'}),('middle-candidate','candidate','representative_combat',{'LABYRINTH_COMBAT_PROFILE':'middle','LABYRINTH_RUNTIME_PERF_SECTIONS':'0'}),('middle-base','base','representative_combat',{'LABYRINTH_COMBAT_PROFILE':'middle','LABYRINTH_RUNTIME_PERF_SECTIONS':'0'})]
items=items[2:6]+items[:2]+items[6:]
def snapshot(repo,env):
 tracked=subprocess.check_output(['git','ls-files','-z'],cwd=repo).decode().split('\0')
 files=list(repo.joinpath('scripts').rglob('*.gd'))+[repo/name for name in tracked if name and Path(name).suffix in ('.tscn','.tres','.gdshader')]+[repo/'project.godot',repo/'tests/runtime_frame_performance_benchmark.gd',repo/'tests/representative_combat_performance_benchmark.gd',repo/'tools/performance_pass.py',repo/'tools/visual_probe_runner.py']
 return {'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'environment':env,'snapshot_scope':'All recursive scripts/**/*.gd, tracked Godot scenes/resources/shaders, project.godot, named harnesses/runners; binary assets are not hashed here.','git_status':subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True),'files':{str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files) if p.exists()}}
items=[('reduced-repeat-candidate','candidate','runtime_frame',{**focused,'LABYRINTH_RUNTIME_PERF_REDUCED_MOTION':'1'}),('reduced-repeat-base','base','runtime_frame',{**focused,'LABYRINTH_RUNTIME_PERF_REDUCED_MOTION':'1'})]
for label,build,bench,extra in items:
 repo=repos[build];env={k:v for k,v in os.environ.items() if not k.startswith(('LABYRINTH_RUNTIME_PERF_','LABYRINTH_COMBAT_PROFILE'))};env.update(extra)
 name='sept18-final4-'+label
 before=snapshot(repo,extra);(root/(name+'-sources.json')).write_text(json.dumps(before,indent=2)+'\n')
 print('START',name,flush=True)
 with (root/(name+'.log')).open('w') as f:
  r=subprocess.run(['python3','tools/performance_pass.py','run','--task-id',name,'--native','--benchmark',bench,'--timeout','300','--output',str(root/(name+'.json'))],cwd=repo,env=env,stdout=f,stderr=subprocess.STDOUT)
 assert snapshot(repo,extra)==before,'Source changed during '+name
 print('DONE',name,r.returncode,flush=True)
 if r.returncode:raise SystemExit(r.returncode)
 x=json.load(open(root/(name+'.json')))['benchmarks'][bench]['result']
 assert x.get('probe_unfocused_observations',0)==0 and not x.get('semantic_errors',[]),(name,'invalid focus/semantics')
