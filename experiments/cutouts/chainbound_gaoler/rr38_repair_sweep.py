"""Bounded native-pocket source measurement; output is case-owned build data."""
from concurrent.futures import ThreadPoolExecutor
import collections
from pathlib import Path
import subprocess
import sys
from rr38_case import CASE, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest


def run():
    root=CASE/'proof/logs/feedback2'
    triage=root/'triage_source/triage.json';data=read_json(triage)
    keys={(r['view'],r['clip'],r['frame']) for r in data['records'] if r['kind']=='gate' and r['classification']=='a_native' and r.get('native_joint_pockets')}
    def job(start):
        target=root/f'repairs/{start:04d}.json';target.parent.mkdir(exist_ok=True)
        command=[sys.executable,'-B','experiments/cutouts/chainbound_gaoler/rr38_repair_measurements.py',
            '--case',str(root/'baseline_source'),'--treated-case',str(root/'baseline_treated'),
            '--native',str(CASE/'proof/native'),'--retained',str(root/'round0_case'),
            '--triage',str(triage),'--output',str(target),'--start',str(start),'--count','4']
        result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=90)
        target.with_suffix('.log').write_text(result.stdout+result.stderr)
        if result.returncode:raise ValueError('Measurement failed: '+str(target.with_suffix('.log')))
        print(result.stdout.strip(),flush=True)
        return read_json(target)
    with ThreadPoolExecutor(max_workers=2) as pool:reports=list(pool.map(job,range(0,len(keys),4)))
    targets=collections.defaultdict(set)
    for report in reports:
        for view,parts in report['targets'].items():
            for name,points in parts.items():targets[view,name].update(map(tuple,points))
    seam=read_json(CASE/'proof/feedback2_seam.json')
    targets['rear','hidden_leg_near'].update(map(tuple,seam['source_targets']))
    fills=collections.defaultdict(set)
    for row in data['records']:
        if row['kind']=='flat' and row['classification']=='a_native':fills[row['view']].add(row['finding']['piece'])
    config={'rule':'Director feedback 2: same-piece same-row interior continuation; measured native seam source bands.',
        'native_manifest_sha256':data['native_manifest_sha256'],'triage_log_sha256':digest(triage),
        'targets':{view:{name:[list(p) for p in sorted(points,key=lambda p:(p[1],p[0]))] for (v,name),points in sorted(targets.items()) if v==view} for view in ('front','rear')},
        'row_fills':{view:sorted(pieces) for view,pieces in fills.items()}}
    write_json(CASE.parent/'rr38_feedback2_continuations.json',config)
    write_json(root/'repair_measurements.json',{'pockets':[r for p in reports for r in p['pockets']],**config})
    print('RR38 REPAIR INVENTORY: '+str(sum(len(p) for p in targets.values()))+' source targets; '+str(sum(len(p) for p in fills.values()))+' own-row fill surfaces')


if __name__=='__main__':run()
