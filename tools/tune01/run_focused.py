#!/usr/bin/env python3
"""Run only tune-01's requested focused proof after the proposal is written."""
from concurrent.futures import ThreadPoolExecutor
import argparse
import json
from pathlib import Path
import shlex
import subprocess
import sys
import time
from report import OUT, ROOT, archive

FOCUSED_WORKERS = 2
FOCUSED_TIMEOUT_SECONDS = 300
COUNT_MATRIX_TIMEOUT_SECONDS = 600  # 22,656 placement layouts; known long sweep.
PROGRAMS = [
    ('enemy_count','tools/tune01/focused.gd',['--suite','enemy-count'], 'TUNE01_FOCUSED enemy-count: PASS'),
    ('warband','tests/warband_test.gd',[], 'Warband suite: 0 failures'),
    ('snare','tests/snare_test.gd',[], 'Snare suite: 0 failures'),
    ('last_light','tests/last_light_test.gd',[], 'Last Light suite: 0 failures'),
    ('hoarder','tests/hoarder_test.gd',[], 'Hoarder suite: 0 failures'),
    ('guardian','tools/tune01/focused.gd',['--suite','guardian'], 'TUNE01_FOCUSED guardian: PASS'),
    ('guardian_rules','tests/guardian_rules_test.gd',[], 'GUARDIAN RULES TEST RESULT: PASS'),
    ('dragon','tools/tune01/focused.gd',['--suite','dragon'], 'TUNE01_FOCUSED dragon: PASS'),
    ('area01','tests/dragon_committed_patterns_test.gd',[], 'Dragon committed patterns passed.'),
    ('analytics','tests/encounter_analytics_test.gd',[], 'ENCOUNTER ANALYTICS: PASS'),
    ('save_resume','tests/save_resume_boundary_test.gd',[], 'TEST RESULT: PASS'),
    ('events_omens','tests/event_rules_test.gd',[], 'Event rules suite: 0 failures'),
    ('tier_rules','tools/tune01/check.gd',[], 'TUNE01_RULES_CHECK: PASS'),
]

def main(only=None):
    directory=OUT/'focused_final';directory.mkdir(exist_ok=True)
    previous=json.loads((OUT/'focused_final_results.json').read_text()) if only else []
    histories={}
    for record in previous:
        if record['name'] not in only:continue
        history=record.get('previous_attempts',[])
        log=Path(record['log_path'])
        backup=log.with_name(f'{log.stem}.attempt{len(history)+1}.log')
        log.rename(backup)
        history.append({**{k:v for k,v in record.items() if k!='previous_attempts'},'log_path':str(backup)})
        histories[record['name']]=history
    def run(program):
        name,script,args,marker=program
        timeout=COUNT_MATRIX_TIMEOUT_SECONDS if name=='enemy_count' else FOCUSED_TIMEOUT_SECONDS
        cmd=[sys.executable,'tools/godot_task_runner.py','--task-id','tune-01','--timeout',str(timeout),'--stream','--','godot','--headless','--path','.','--script',script]
        if args:cmd+=['--',*args]
        log=directory/f'{name}.log';start=time.time()
        with log.open('w') as f:result=subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
        output=log.read_text()
        record=dict(name=name,command='cd '+shlex.quote(str(ROOT))+' && '+shlex.join(cmd),returncode=result.returncode,elapsed_seconds=time.time()-start,passed=result.returncode==0 and marker in output,
                    result_lines=[line for line in output.splitlines() if marker in line],log_path=str(log))
        if name in histories:record['previous_attempts']=histories[name]
        print(f"TUNE01_FOCUSED_FINAL {name}: {'PASS' if record['passed'] else 'FAIL'} ({record['elapsed_seconds']:.1f}s)",flush=True)
        return record
    programs=[p for p in PROGRAMS if not only or p[0] in only]
    with ThreadPoolExecutor(max_workers=FOCUSED_WORKERS) as pool:results=list(pool.map(run,programs))
    if not only or 'ui_identity' in only:
        cmd=[sys.executable,'tests/test_ui_identity_lint.py']
        result=subprocess.run(cmd,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        log=directory/'ui_identity.log';log.write_text(result.stdout)
        results.append(dict(name='ui_identity',command='cd '+shlex.quote(str(ROOT))+' && '+shlex.join(cmd),returncode=result.returncode,passed=result.returncode==0,log_path=str(log),result_lines=[line for line in result.stdout.splitlines() if line=='OK' or line.startswith('Ran ')]))
        if 'ui_identity' in histories:results[-1]['previous_attempts']=histories['ui_identity']
    if only:results=[r for r in previous if r['name'] not in only]+results
    (OUT/'focused_final_results.json').write_text(json.dumps(results,indent=2)+'\n')
    archive(OUT/'focused_final_logs.jsonl.gz',[{**r,'text':Path(r['log_path']).read_text(),'previous_attempts':[{**a,'text':Path(a['log_path']).read_text()} for a in r.get('previous_attempts',[])]} for r in results])
    failed=[r['name'] for r in results if not r['passed']]
    print(f'TUNE01_FOCUSED_FINAL: {len(results)-len(failed)}/{len(results)} passed; failed={failed}',flush=True)
    return bool(failed)

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--only',nargs='+',choices=[p[0] for p in PROGRAMS]+['ui_identity'])
    sys.exit(main(ap.parse_args().only))
