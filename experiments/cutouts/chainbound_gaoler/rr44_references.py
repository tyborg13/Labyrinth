"""Per-rig runtime preservation and report-only foreign elbow audit (<90s)."""
import argparse
import os
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import numpy as np
from PIL import Image
from rr44_case import PROJECT, CASE, DEFAULTS
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.elbows import report
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case

RIGS = {'seer':'hoarfrost_seer/rr10','thrall':'arc_thrall/rr11','mirror':'glacial_mirror/rr18',
        'weaver':'briar_weaver/mq9','mimic':'hollow_mimic/rr29','mortar':'slag_mortar/rr30',
        'herald':'gale_herald/mq12','gloam':'gloam_stalker/rr35','lancer':'frostglass_lancer/rr37'}
CHANGED_RUNTIME = ('humanoid_motion.gd','humanoid_gait.gd','humanoid_presentation.gd','humanoid_held_follow.gd','rig.gd')


def sample(case, output, project=PROJECT):
    run = subprocess.run([sys.executable,str(PROJECT/'tools/godot_task_runner.py'),'--task-id',os.environ.get('LABYRINTH_TASK_ID','rr-49'),'--timeout','85','--stream','--',
          'godot','--headless','--path',str(project),'--script','tests/rr38/samples.gd','--','--case',str(case),'--output',str(output)],
          cwd=PROJECT,capture_output=True,text=True,timeout=DEFAULTS['sample_timeout_s']+2)
    if run.returncode: raise ValueError(run.stdout+run.stderr)
    return read_json(output)


def prior_project(folder):
    """Read-only Git snapshot of the affected runtime; no task Git mutation."""
    folder=Path(folder)
    for path in PROJECT.iterdir():
        if path.name in ('.git','scripts'): continue
        (folder/path.name).symlink_to(path,target_is_directory=path.is_dir())
    (folder/'scripts').mkdir()
    for path in (PROJECT/'scripts').iterdir():
        if path.name=='maquette_cutout_runtime': continue
        (folder/'scripts'/path.name).symlink_to(path,target_is_directory=path.is_dir())
    target=folder/'scripts/maquette_cutout_runtime';target.mkdir()
    for path in (PROJECT/'scripts/maquette_cutout_runtime').iterdir():
        if path.name in CHANGED_RUNTIME:
            (target/path.name).write_bytes(subprocess.check_output(['git','show','HEAD:'+str(path.relative_to(PROJECT))],cwd=PROJECT))
        else: (target/path.name).symlink_to(path,target_is_directory=path.is_dir())
    return folder


def crop(case, layout, pose, destination):
    with for_case(case):
        layers,_=CpuPose(case,layout,native_skin=True).layers(pose)
        actual=np.zeros_like(layers[0][1])
        for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']): actual[image[...,3]>0]=image[image[...,3]>0]
        yy,xx=np.nonzero(actual[...,3]);pad=DEFAULTS['crop_context_px']
        box=(int(xx.min())-pad,int(yy.min())-pad,int(xx.max()+1)+pad,int(yy.max()+1)+pad)
        picture=Image.fromarray(actual).crop(box);zoom=DEFAULTS['crop_zoom']
        destination.parent.mkdir(parents=True,exist_ok=True)
        picture.resize((picture.width*zoom,picture.height*zoom),Image.Resampling.NEAREST).save(destination,lossless=True,exact=True)


def run(name, output):
    case=PROJECT/'experiments/cutouts'/RIGS[name];data=read_json(case/'compiled_motion.json')
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='rr44-reference-') as temporary:
        folder=Path(temporary);prior=(folder/'prior');prior.mkdir();prior_project(prior)
        before=sample(case,folder/'before.json',prior);after=sample(case,folder/'after.json')
    # Resource-binding hashes intentionally differ. Every emitted pose and
    # actual painted-node transform must match exactly, with no tolerance.
    identical=json.dumps(before['samples'],sort_keys=True)==json.dumps(after['samples'],sort_keys=True)
    if not identical: raise ValueError('Foreign runtime changed: '+name)
    failures=[];witnesses=[]
    for view in data['view_tracks']:
        layout=read_json(case/f'layouts/{view}.json')
        result=report(layout,data,dict(samples=[r for r in after['samples'] if r['kind']=='presented']),require_policy=False,threshold=2)
        bad=[r for r in result['frames'] if not r['passed']];failures+=bad
        for clip in data['clips']:
            choices=[r for r in bad if r['clip']==clip]
            if not choices: continue
            worst=min(choices,key=lambda r:r['signed_flexion_deg'])
            pose=next(r for r in after['samples'] if (r['view'],r['clip'],r['frame'],r['kind'])==(view,clip,worst['frame'],'presented'))
            path=output/f'{name}_{view}_{clip}_{pose["frame"]:03d}_cpu_4x.webp'
            crop(case,layout,pose,path)
            witnesses.append(dict(**worst,crop=str(path.relative_to(output)),sha256=digest(path)))
    result=dict(rig=name,case=RIGS[name],runtime_byte_identical=identical,samples=len(after['samples']),native_pixels=False,
                report_only=True,threshold_deg=2,failures=failures,witnesses=witnesses,
                unchanged_files={str(p.relative_to(PROJECT)):digest(p) for p in [case/'compiled_motion.json',*[case/f'layouts/{v}.json' for v in data['view_tracks']]]})
    write_json(output/f'{name}.json',result)
    print(f'RR44 REFERENCE {name.upper()}: PASS ({len(after["samples"])} byte-identical poses; elbow report-only: {len(failures)} failing frames, {len(witnesses)} crops)')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--rig',choices=RIGS,required=True)
    parser.add_argument('--output',type=Path,default=CASE/'proof/other_elbows')
    args=parser.parse_args();run(args.rig,args.output)
