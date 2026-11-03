"""Run the same complete CPU gate in independent clip shards, then bind the union."""
import subprocess
import sys
from pathlib import Path
from rr52_build import ROOT,CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings

CLIP_SHARDS=(('idle','move','snuff'),('mourning_hook','last_procession'),('hit','death'))


def run(case=CASE):
    bound=bindings(case);jobs=[];folder=case/'proof/cpu_shards';folder.mkdir(exist_ok=True)
    for index,clips in enumerate(CLIP_SHARDS):
        output=folder/f'{index}.json';log=(folder/f'{index}.log').open('w')
        output.unlink(missing_ok=True)
        command=[sys.executable,'-B','experiments/cutouts/last_lamplighter/rr52_joint_budget.py','--case',str(case),'--clips',','.join(clips),'--output',str(output)]
        jobs.append((subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT),output,log))
    reports=[]
    for process,output,log in jobs:
        code=process.wait();log.close()
        if code not in (0,1) or not output.exists():raise ValueError('CPU shard did not produce its report: '+str(output))
        report=read_json(output)
        if report['inputs']!=bound:raise ValueError('CPU shard input mismatch')
        reports.append(report)
    samples_path=case/'proof/raster_samples.json';samples=read_json(samples_path);frames=sum(r['frames'] for r in reports)
    if frames!=len(samples['samples']) or bindings(case)!=bound:raise ValueError('Incomplete/stale CPU union')
    errors=[e for r in reports for e in r['errors']];result={'ok':not errors,'errors':errors,'frames':frames,'joint_checks':sum(r['joint_checks'] for r in reports),'authorized_air_pockets':sum(r['authorized_air_pockets'] for r in reports),'air_pockets':[p for r in reports for p in r['air_pockets']],'cap_requests':[p for r in reports for p in r.get('cap_requests',[])],'outline':[p for r in reports for p in r.get('outline',[])],'accepted_short_tears':[p for r in reports for p in r.get('accepted_short_tears',[])],'raw_joint_holes':[p for r in reports for p in r.get('raw_joint_holes',[])],'native_pixels':False,'inputs':bound,'samples_sha256':digest(samples_path),'clip_shards':CLIP_SHARDS,'method':reports[0]['method'],'defaults':dict(reports[0]['defaults'],workers=len(CLIP_SHARDS))}
    write_json(case/'proof/cpu_sweep.json',result)
    print('RR52 CPU SWEEP: %s (%d frames; %d receiver surfaces; %d findings)'%('PASS' if result['ok'] else 'FINDINGS',frames,result['joint_checks'],len(errors)))
    return result['ok']

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--case',type=Path,default=CASE);args=parser.parse_args();raise SystemExit(int(not run(args.case)))
