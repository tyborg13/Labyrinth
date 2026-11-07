from pathlib import Path
import json
import subprocess

ROOT=Path('/Users/borgerding/workspace/Labyrinth.worktrees/perf-65')
OUT=Path('/private/tmp/labyrinth_codex/perf-65/feedback-1-checks')
SCRIPTS=['tests/perf/run_save_worker_test.gd','tests/perf/background_persistence_test.gd',
         'tests/perf/deferred_deadline_test.gd','tests/save_pipeline_performance_test.gd',
         'tests/save_resume_boundary_test.gd','tests/surface_save_migration_test.gd',
         'tests/skill_progression_analytics_test.gd']
OUT.mkdir(exist_ok=True)
rows=[]
for script in SCRIPTS:
    command=['python3','tools/godot_task_runner.py','--task-id','perf-65','--stream','--','godot','--headless','--path','.', '--script',script]
    result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    (OUT/(Path(script).stem+'.log')).write_text(result.stdout)
    rows.append({'script':script,'command':command,'exit_code':result.returncode,
                 'result_lines':[line for line in result.stdout.splitlines() if 'RESULT:' in line or 'TEST RESULT:' in line or 'Surface migration checks:' in line]})
    print(script,result.returncode,rows[-1]['result_lines'],flush=True)
    (OUT/'results.json').write_text(json.dumps(rows,indent=2))
    if result.returncode:raise SystemExit(result.returncode)
print('PERF65 FEEDBACK FOCUSED SAVES: PASS (7 programs)')
