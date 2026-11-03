"""Bounded, descending uniform channel-scale search on measured posed skins.

This only writes ignored candidate cases. Chain angle/release/drop retain the
protected motion, so landing semantics are not weakened to hide limb defects.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import time
from PIL import Image
from rr38_case import CASE,PROJECT
from rr38_triage import compose,crop
from rr38_cpu_diagnostics import Diagnostics
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case

SCALE_DENOMINATOR=60
CHILD_TIMEOUT_SECONDS=90
TRIANGLE_BATCH_SIZE=128
# Early rejection witnesses; survivors must still pass every presented frame.
WITNESSES={'press':[14,37,20,13],'death':[37,50,95],'reel':[29,33,38]}


def prepare(base,output,clip,scale):
    output.mkdir(parents=True,exist_ok=True)
    for p in base.iterdir():
        if p.name=='proof':continue
        target=output/p.name
        if p.is_dir():shutil.copytree(p,target,dirs_exist_ok=True)
        else:shutil.copyfile(p,target)
    data=read_json(output/'compiled_motion.json');peaks={}
    for view,clips in data['view_tracks'].items():
        peaks[view]={}
        for track in clips[clip]:
            if track['bone']=='chain':continue
            for key in track['keys']:key['value']*=scale
            values=[k['value'] for k in track['keys']]
            peaks[view][track['source']]=[min(values),max(values)]
        p=output/f'layouts/{view}.json';layout=read_json(p)
        layout['motion_data']='res://'+str((output/'compiled_motion.json').relative_to(PROJECT))
        write_json(p,layout)
    write_json(output/'compiled_motion.json',data)
    return peaks


def sample(case,clip,frames):
    command=[sys.executable,'tools/godot_task_runner.py','--task-id','rr-38','--stream','--','godot','--headless','--path','.',
        '--script','tests/rr38/samples.gd','--','--case',str(case),'--output',str(case/'proof/logs/samples.json'),
        '--clips',clip,'--presented-only']
    if frames is not None:command+=['--frames',','.join(map(str,frames))]
    result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=CHILD_TIMEOUT_SECONDS)
    (case/'process.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise ValueError(result.stdout+result.stderr)


def check(case,clip,scale,view,frame,output):
    data=read_json(case/'proof/logs/samples.json')
    row=next(r for r in data['samples'] if (r['view'],r['clip'],r['frame'])==(view,clip,frame))
    model=CpuPose(case,read_json(case/f'layouts/{view}.json'),triangle_batch_size=TRIANGLE_BATCH_SIZE,native_skin=True)
    gate=Diagnostics(case,model)
    with for_case(case):
        layers,maps=model.layers(row);report=gate.measure(row,layers,maps)
    errors=sorted(set(report['kinds'])&{'seam','missing'})
    image=compose(layers);output.mkdir(parents=True,exist_ok=True)
    Image.fromarray(image).save(output/'pose.png')
    report.update(view=view,clip=clip,frame=frame,scale=scale,tear_free=not errors)
    report['crops']=[crop(image,p['bbox'],output/f'seam_{n}.png') for n,p in enumerate(report['source_space']['failures'])]
    write_json(output/'report.json',report)
    return report


def search(base,clip,output,scales):
    rows=[];best=None
    for scale in scales:
        case=output/f'candidate_{scale:.6f}'
        peaks=prepare(base,case,clip,scale)
        sample(case,clip,WITNESSES[clip])
        # Each expensive frame is isolated in its own budgeted process.
        jobs=[(v,f) for v in ('front','rear') for f in WITNESSES[clip]]
        def job(key):
            v,f=key;folder=case/f'checks_run/{v}_{f}'
            cmd=[sys.executable,'-B',__file__,'frame','--case',str(case),'--clip',clip,'--scale',str(scale),'--view',v,'--frame',str(f),'--output',str(folder)]
            began=time.monotonic();r=subprocess.run(cmd,cwd=PROJECT,capture_output=True,text=True,timeout=CHILD_TIMEOUT_SECONDS)
            if r.returncode not in (0,1):raise ValueError(r.stdout+r.stderr)
            report=read_json(folder/'report.json');report['seconds']=time.monotonic()-began
            return report
        reports=[]
        for key in jobs:
            report=job(key);reports.append(report)
            if not report['tear_free']:break
        failures=[r for r in reports if not r['tear_free']]
        row={'scale':scale,'peaks':peaks,'witnesses':reports,'witness_failures':len(failures)};rows.append(row)
        print(f'RR38 {clip.upper()} SCALE {scale:.6f}: {"REJECT" if failures else "WITNESSES CLEAR"} ({len(failures)}/{len(reports)} tearing witnesses)',flush=True)
        write_json(output/'search.json',{'clip':clip,'scale_denominator':SCALE_DENOMINATOR,'native_acceptance':False,'candidates':rows,'best':best})
        if not failures:
            best=scale
            write_json(output/'search.json',{'clip':clip,'scale_denominator':SCALE_DENOMINATOR,'native_acceptance':False,'candidates':rows,'best_witness_scale':best})
            # A witness pass is only a candidate; never apply it to production
            # until a full presented-frame sweep has passed.
            break
    return rows


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=('search','frame'))
    p.add_argument('--case',type=Path,required=True);p.add_argument('--clip',choices=tuple(WITNESSES),required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--scale',type=float,default=1)
    p.add_argument('--view',choices=('front','rear'));p.add_argument('--frame',type=int)
    p.add_argument('--scales',default=','.join(str(n/SCALE_DENOMINATOR) for n in range(SCALE_DENOMINATOR,39,-1)))
    a=p.parse_args();a.case=a.case.resolve();a.output=a.output.resolve()
    if a.mode=='frame':raise SystemExit(not check(a.case,a.clip,a.scale,a.view,a.frame,a.output)['tear_free'])
    search(a.case,a.clip,a.output,[float(v) for v in a.scales.split(',')])
