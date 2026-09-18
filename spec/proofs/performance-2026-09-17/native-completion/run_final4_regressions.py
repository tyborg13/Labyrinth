import hashlib,json,subprocess
from pathlib import Path
root=Path('/tmp/labyrinth-perf-2026-09-17')
repo=Path('/Users/borgerding/workspace/Labyrinth.worktrees/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio')
def snapshot():
 return {str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for directory in ['scripts','tests'] for p in sorted((repo/directory).rglob('*.gd'))}
before=snapshot()
scripts=['run_tests','enemy_route_allocation_equivalence_test','performance_phase_fast_path_test','elemental_fx_hash_equivalence_test','card_proxy_pool_test','committed_hand_queries_test','board_hover_coalescing_test','combat_boundary_equivalence_test','forced_movement_query_equivalence_test','combat_analytics_context_equivalence_test','profile_read_equivalence_test','save_resume_boundary_test','surface_analytics_batch_test','board_surface_presentation_test','card_draw_hand_flow_test']
for script in scripts:
 with (root/('sept18-final4-'+script+'.log')).open('w') as f:
  result=subprocess.run(['python3','tools/godot_task_runner.py','--task-id','sept18-final4-'+script,'--stream','--','godot','--headless','--path','.','--script','tests/'+script+'.gd'],cwd=repo,stdout=f,stderr=subprocess.STDOUT)
 print(script,result.returncode,flush=True)
 if result.returncode: raise SystemExit(result.returncode)
assert snapshot()==before
(root/'sept18-final4-regression-sources.json').write_text(json.dumps({'files':before,'checks':scripts,'source_invariant':True},indent=2)+'\n')
