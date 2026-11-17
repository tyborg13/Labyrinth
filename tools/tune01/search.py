#!/usr/bin/env python3
"""Bounded four-worker, background-priority tune-01 stat search (no bot edits)."""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
import os
from pathlib import Path
import shlex
import subprocess
import sys
import threading
import time
from report import BASE, OUT, ROOT, SECTIONS, KINDS, CENTRES, archive, baseline, cost, key, kind, read, render, summarize, supplement

WORKERS = 4
WALL_SECONDS = 4*60*60
BATCH_SIZE = 4
PROBE_N = 48
CONFIRM_N = 96
# Each depth control has N=96, so native reweighting can use exact seed/repeat
# controls even for rare kinds with more repeats than the pooled normal cohort.
NORMAL_REPEATS = 12
RESERVE_SECONDS = 120
PLANNING_TIMEOUT_SECONDS = 600

def write(path, value): path.write_text(json.dumps(value,indent=2)+'\n')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main(scratch):
    scratch.mkdir(parents=True,exist_ok=True)
    OUT.mkdir(parents=True,exist_ok=True)
    started=json.loads((OUT/"search_contract.json").read_text())["started_unix"] if (OUT/"search_contract.json").exists() else time.time()
    deadline=started+WALL_SECONDS-RESERVE_SECONDS
    commands=json.loads((OUT/"commands.json").read_text()) if (OUT/"commands.json").exists() else []
    lock=threading.Lock()
    failures=[]
    base=baseline()
    contract=dict(started_unix=started,deadline_unix=deadline,max_workers=WORKERS,background_priority="Godot Thread.PRIORITY_LOW / macOS Utility QoS",background_priority_verified=True,active_fight_batches=WORKERS,wall_seconds_limit=WALL_SECONDS,
                  probe_n=PROBE_N,confirm_n=CONFIRM_N,normal_n_per_section_depth=96,
                  policy_sha256=sha(ROOT/'tools/encounter_bot.gd'),
                  source_sha256={str(p.relative_to(ROOT)):sha(p) for p in [*sorted((ROOT/'scripts').rglob('*.gd')),*sorted((ROOT/'data').rglob('*.json'))]},
                  measurement_tool_sha256={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'tools/tune01').glob('*') if p.suffix in ('.py','.gd')},
                  chosen_defaults=dict(batch_size=BATCH_SIZE,normal_repeats=NORMAL_REPEATS,reserve_seconds=RESERVE_SECONDS,planning_timeout_seconds=PLANNING_TIMEOUT_SECONDS),
                  status='running')
    write(OUT/'search_contract.json',contract)
    def execute(script,args,log,timeout):
        cmd=[sys.executable,'tools/godot_task_runner.py','--task-id','tune-01','--timeout',str(timeout),'--stream','--','godot','--headless','--path','.','--script',script,'--',*map(str,args)]
        before=time.time()
        with log.open('w') as f:
            run=subprocess.run(cmd,cwd=ROOT,env={**os.environ,'LABYRINTH_CEL_LOOK':'off'},stdout=f,stderr=subprocess.STDOUT)
        rec=dict(command='cd '+shlex.quote(str(ROOT))+' && '+shlex.join(cmd),log=str(log),started_unix=before,elapsed_seconds=time.time()-before,returncode=run.returncode)
        with lock:
            commands.append(rec)
            write(OUT/'commands.json',commands)
        if run.returncode:
            failures.append(rec)
            if time.time()<deadline: raise RuntimeError(f'Worker failed: {log}')
    # Unchanged archived native-room inputs preserve all design-owner assets,
    # seeded native identities and typed frozen ladder snapshots.
    plan=read(BASE/'inputs.jsonl.gz')
    for i,t in enumerate(plan):
        path=scratch/f'input-{i}.bin'
        path.write_bytes(base64.b64decode(t.pop('typed_payload_base64')))
        t['input_file']=str(path)
        assert sha(path)==t['input_sha256']
    entries=read(BASE/'entry_loadouts.jsonl.gz')
    for entry in entries:
        (scratch/f"entry-{entry['ladder_seed']}-{entry['section']}.bin").write_bytes(base64.b64decode(entry['typed_payload_base64']))
    archive(OUT/'entry_loadouts.jsonl.gz',entries)
    controls={}
    stages={}
    batch_counter=1+max((int(p.stem.split("-")[1]) for p in scratch.glob("batch-*.json")), default=-1)
    def jobs_for(cell,n,dials,stage):
        section,cellkind=cell
        eligible=[t for t in plan if t['section']==section and kind(t)==cellkind]
        eligible.sort(key=lambda t:(t['ladder_seed'],t['room_coord']))
        jobs=[]
        for index in range(n):
            t=eligible[index%len(eligible)].copy()
            repeat=index//len(eligible)
            t.update(dials=dials,stage=stage)
            task=scratch/f'task-{stage}-s{section}-{cellkind}-{index}.json'
            write(task,t)
            jobs.append(dict(task=str(task),repeat=repeat,output=str(scratch/f'fight-{stage}-s{section}-{cellkind}-{index}.jsonl')))
        return jobs
    def run_jobs(jobs):
        nonlocal batch_counter
        paths=[]
        pending=[j for j in jobs if not Path(j["output"]).exists()]
        for offset in range(0,len(pending),BATCH_SIZE):
            path=scratch/f'batch-{batch_counter}.json';batch_counter+=1
            write(path,pending[offset:offset+BATCH_SIZE]);paths.append(path)
        def run(path):
            if time.time()>=deadline:return
            execute('tools/tune01/measure.gd',['--jobs',path,'--deadline-unix',deadline],path.with_suffix('.log'),max(1,deadline-time.time()))
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:list(pool.map(run,paths))
        return [json.loads(Path(j['output']).read_text()) for j in jobs if Path(j['output']).exists() and Path(j['output']).stat().st_size]
    cells=[(s,k) for s in SECTIONS for k in KINDS]
    def checkpoint():
        for name,rows in stages.items():archive(OUT/f'{name}.jsonl.gz',rows)
        contract.update(elapsed_seconds=time.time()-started,completed_fights=sum(len(r) for r in stages.values()),failures=failures)
        write(OUT/'search_contract.json',contract)
    # Re-measure normal controls after count changes. Round-robin depth/seed
    # order keeps partial sections assessable if the wall budget is reached.
    normaljobs=[]
    for repeat in range(NORMAL_REPEATS):
        for t in plan:
            if t['section'] not in SECTIONS or t['category']!='normal':continue
            task=scratch/f"normal-s{t['section']}-t{t['tier']}-l{t['ladder_seed']}.json"
            write(task,{**t,'dials':{},'stage':'normal'})
            normaljobs.append(dict(task=str(task),repeat=repeat,output=str(scratch/f"fight-normal-s{t['section']}-t{t['tier']}-l{t['ladder_seed']}-r{repeat}.jsonl")))
    # Probe first, so every cell receives its first N=48 before the controls
    # consume the budget. All dials are absolute relative to the raw baseline.
    probes={}
    for s,k in cells:
        b=next(r for r in base if r['section']==s and r['kind']==k)
        gap=b['gap'];centre=CENTRES[k]
        probes[f'{s}:{k}']=[min(175,max(80,int(5*round((100+3*(centre-gap))/5)))),0]
    jobs=[]
    celljobs={c:jobs_for(c,PROBE_N,probes,'probe') for c in cells}
    for i in range(PROBE_N):
        for c in cells:jobs.append(celljobs[c][i])
    pairednormal={}
    for job in jobs:
        t=json.loads(Path(job['task']).read_text())
        match=next(x for x in plan if x['category']=='normal' and x['section']==t['section'] and x['tier']==t['tier'] and x['ladder_seed']==t['ladder_seed'])
        tag=(match['section'],match['tier'],match['ladder_seed'],job['repeat'])
        if tag in pairednormal:continue
        task=scratch/('control-%s.json' % '-'.join(map(str,tag)))
        write(task,{**match,'dials':{},'stage':'normal'})
        pairednormal[tag]=dict(task=str(task),repeat=job['repeat'],output=str(scratch/('fight-control-%s.jsonl' % '-'.join(map(str,tag)))))
    def run_with_controls(jobs, stage):
        combined=[]
        scheduled=set(controls)
        for job in jobs:
            t=json.loads(Path(job['task']).read_text())
            tag=(t['section'],t['tier'],t['ladder_seed'],job['repeat'])
            if tag not in scheduled:
                match=next(x for x in plan if x['category']=='normal' and x['section']==t['section'] and x['tier']==t['tier'] and x['ladder_seed']==t['ladder_seed'])
                task=scratch/('control-%s.json' % '-'.join(map(str,tag)))
                write(task,{**match,'dials':{},'stage':'normal'})
                combined.append(dict(task=str(task),repeat=job['repeat'],output=str(scratch/('fight-control-%s.jsonl' % '-'.join(map(str,tag))))))
                scheduled.add(tag)
            combined.append(job)
        rows=run_jobs(combined)
        for r in rows:
            if r['category']=='normal': controls[key(r)]=r
        stages['normal']=list(controls.values())
        stages[stage]=[r for r in rows if r['stage']==stage]
        checkpoint()
    run_with_controls(jobs,'probe')
    print(f"TUNE01_PROBES_DONE fights={len(stages['probe'])} wall={time.time()-started:.1f}",flush=True)
    proposed={};status={}
    probe_summary=summarize(stages['probe'],controls)
    for s,k in cells:
        ck=f'{s}:{k}';b=next(r for r in base if r['section']==s and r['kind']==k)
        p=next((r for r in probe_summary if r['section']==s and r['kind']==k),{})
        hp,damage=probes[ck]
        if not p.get('paired_n'):proposed[ck]=[hp,damage];status[ck]='probe incomplete; no matched controls';continue
        gap=p['gap'];centre=CENTRES[k]
        if hp==175 and gap<centre-5:
            proposed[ck]=[175,1];status[ck]='damage +1 probe required';continue
        slope=(gap-b['gap'])/(hp-100) if hp!=100 else 0
        target=100+(centre-b['gap'])/slope if slope>0 else hp
        proposed[ck]=[min(175,max(80,int(5*round(target/5)))),0];status[ck]='interpolated confirmation required'
    # Confirm the interpolated Health proposal; capped cells probe damage at
    # N=48 first and increment only while still below their band.
    for damage in range(1,4):
        pending=[c for c in cells if status[f'{c[0]}:{c[1]}']==f'damage +{damage} probe required']
        if not pending or time.time()>=deadline:break
        jobs=[j for c in pending for j in jobs_for(c,PROBE_N,proposed,f'damage{damage}')]
        run_with_controls(jobs,f'damage{damage}')
        sums=summarize(stages[f'damage{damage}'],controls)
        for s,k in pending:
            ck=f'{s}:{k}';p=next((r for r in sums if r['section']==s and r['kind']==k),{})
            if p.get('n')!=PROBE_N or not p.get('paired_n'):status[ck]='damage probe incomplete';continue
            if p['gap']<CENTRES[k]-5:
                if damage<3:proposed[ck]=[175,damage+1];status[ck]=f'damage +{damage+1} probe required'
                else:status[ck]='stats cannot reach band at 175/+3'
            else:status[ck]='confirmation required'
    if time.time()<deadline:
        eligible=[c for c in cells if status[f'{c[0]}:{c[1]}'] in ['confirmation required','interpolated confirmation required']]
        celljobs={c:jobs_for(c,CONFIRM_N,proposed,'confirm') for c in eligible}
        jobs=[celljobs[c][i] for i in range(CONFIRM_N) for c in eligible]
        run_with_controls(jobs,'confirm')
        sums=summarize(stages['confirm'],controls)
        for s,k in eligible:
            p=next((r for r in sums if r['section']==s and r['kind']==k),{})
            status[f'{s}:{k}']='confirmed in band' if p.get('n')==CONFIRM_N and p.get('outside_band')==0 else ('confirmation incomplete' if p.get('n',0)<CONFIRM_N else 'confirmed outside band; redesign/next iteration required')
    confirmed=summarize(stages.get('confirm',[]),controls)
    follow=[c for c in cells if proposed[f'{c[0]}:{c[1]}'][0]==175 and any(r['section']==c[0] and r['kind']==c[1] and r['n']==CONFIRM_N and r.get('gap',1e9)<CENTRES[c[1]]-5 for r in confirmed)]
    for damage in range(1,4):
        pending=[c for c in follow if proposed[f'{c[0]}:{c[1]}'][1]<damage]
        if not pending or time.time()>=deadline:break
        for s,k in pending:proposed[f'{s}:{k}']=[175,damage]
        stage=f'postconfirm_damage{damage}'
        run_with_controls([j for c in pending for j in jobs_for(c,PROBE_N,proposed,stage)],stage)
        sums=summarize(stages[stage],controls)
        follow=[];ready=[]
        for s,k in pending:
            ck=f'{s}:{k}';r=next((r for r in sums if r['section']==s and r['kind']==k),{})
            if r.get('n',0)<PROBE_N:status[ck]='damage probe incomplete';continue
            if r.get('gap',1e9)<CENTRES[k]-5:
                if damage==3:status[ck]='stats cannot reach band at 175/+3'
                else:follow.append((s,k));status[ck]=f'damage +{damage+1} probe required'
            else:ready.append((s,k))
        if ready and time.time()<deadline:
            stage+= '_confirm'
            run_with_controls([j for c in ready for j in jobs_for(c,CONFIRM_N,proposed,stage)],stage)
            for r in summarize(stages[stage],controls):
                if r['kind']=='normal':continue
                ck=f"{r['section']}:{r['kind']}"
                status[ck]='confirmed in band' if r['n']==CONFIRM_N and r.get('outside_band')==0 else ('confirmation incomplete' if r['n']<CONFIRM_N else 'confirmed outside band')
    if time.time()<deadline:
        pendingnormals=[]
        for j in normaljobs:
            t=json.loads(Path(j['task']).read_text())
            if (t['section'],t['tier'],t['ladder_seed'],j['repeat']) not in controls:pendingnormals.append(j)
        for r in run_jobs(pendingnormals):controls[key(r)]=r
        stages['normal']=list(controls.values());checkpoint()
    table=json.loads((ROOT/'data/difficulty_tiers.json').read_text())
    for k in KINDS:
        category=k if k in ['guardian','boss'] else 'objective'
        entry=table['tiers'][category][k if category=='objective' else 'default']
        for field,i in [('hp_percent',0),('damage_bonus',1)]:
            vals=[proposed[f'{s}:{k}'][i] for s in SECTIONS]
            midpoint=lambda a,b:int(5*math.floor((a+b)/10+.5)) if i==0 else (a+b)/2
            entry[field]=[vals[0],midpoint(*vals[:2]),vals[1],midpoint(*vals[1:]),vals[2],vals[2]]
            if i==1:
                for section in (1,3):
                    value=entry[field][section]
                    if value!=int(value):
                        entry.setdefault('damage_bonus_neighbour_means',{})[str(section)]=value
                        entry[field][section]=f'TODO_DESIGN_{k.upper()}_S{section}_FRACTIONAL_DAMAGE_ROUNDING'
                    else:entry[field][section]=int(value)
        entry['section_provenance']=[status[f'0:{k}'],'interpolated',status[f'2:{k}'],'interpolated',status[f'4:{k}'],'copied_s4']
    table['section_provenance']=['measured','interpolated','measured','interpolated','measured','copied_s4']
    # Integer combat amounts cannot express a fractional neighbour mean. Leave
    # a named design placeholder and preserve that mean alongside it.
    write(ROOT/'data/difficulty_tiers.json',table)
    write(OUT/'proposals.json',dict(probe=probes,proposed=proposed,status=status))
    contract.update(status='budget reached' if time.time()>=deadline else 'finished',elapsed_seconds=time.time()-started)
    write(OUT/'search_contract.json',contract)
    report='# tune-01 proposed stat search\n\n'+f"Wall time {contract['elapsed_seconds']:.1f}s; peak workers ≤4, four low-priority simulation threads (macOS Utility QoS; process nice unavailable). Bot SHA {contract['policy_sha256']}.\n\n"
    for name,rows in stages.items():report+='## '+name+'\n\n'+render(summarize(rows,controls))+'\n'+supplement(rows,controls)+'\n'
    report+='## Cell status\n\n'+'\n'.join(f'- {c}: {status[c]}; proposed hp/damage {proposed[c]}' for c in proposed)+'\n'
    (OUT/'search.md').write_text(report)
    archive(OUT/'worker_logs.jsonl.gz',[dict(path=str(p),text=p.read_text()) for p in scratch.glob('*.log')])
    print(f"TUNE01_SEARCH_DONE fights={contract['completed_fights']} wall_seconds={contract['elapsed_seconds']:.1f} status={contract['status']}",flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--scratch-dir',type=Path,required=True)
    main(ap.parse_args().scratch_dir.resolve())
