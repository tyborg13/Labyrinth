"""Reproducible channel-only floor witnesses; never promote failing motion."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from rr42_underlay import CASE,PROJECT
from rr42_density import PROOF_CASE
from rr42_sweep import sweep
from cutout_pipeline.cases import read_json,write_json

FLOOR_CHANNELS={'press':{'hand_near.lift_px':10/22,'hand_near.forward_px':12/18},
                'death':{'pelvis.lift_px':10/15,'hand_far.lift_px':0}}
# The death shoulder witness also tests the chain arm all the way to rest.
# All other authored channels and every timing/release/drop value remain exact.


def prepare(clip,profile):
    output=CASE/'proof/limits'/(clip+'_'+profile)
    scales=FLOOR_CHANNELS[clip].copy()
    if profile=='hip-rest': scales={'pelvis.lift_px':0}
    elif profile=='relaxed':
        scales.update({name:0 for name in ('pelvis.forward_px','torso.lean_deg','torso.forward_px','head.lean_deg')})
    shutil.copytree(PROOF_CASE,output,dirs_exist_ok=True,ignore=shutil.ignore_patterns('proof'))
    data=read_json(output/'compiled_motion.json')
    for view in data['view_tracks']:
        for track in data['view_tracks'][view][clip]:
            factor=scales.get(track['source'],1)
            if profile=='all-rest' and track['source']!='pelvis.lift_px' and not track['source'].startswith('chain.'):
                factor=0
                scales[track['source']]=factor
            for key in track['keys']:key['value']*=factor
        layout=read_json(output/f'layouts/{view}.json')
        layout['motion_data']='res://'+str(output.relative_to(PROJECT)/'compiled_motion.json')
        write_json(output/f'layouts/{view}.json',layout)
    write_json(output/'compiled_motion.json',data)
    write_json(output/'channel_scales.json',scales)
    subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-42','--stream','--','godot','--headless','--path','.',
        '--script','tests/rr38/samples.gd','--','--case',str(output),'--clips',clip,'--output',str(output/'proof/logs/samples.json')],cwd=PROJECT,check=True)
    return output


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--clip',choices=tuple(FLOOR_CHANNELS),required=True)
    parser.add_argument('--profile',choices=('floors','hip-rest','relaxed','all-rest'),default='floors')
    args=parser.parse_args();case=prepare(args.clip,args.profile);result=sweep(case,args.clip,False)
    print('RR42 %s FLOOR WITNESS: %s (no production clamp applied)'%(args.clip.upper(),'PASS' if result['ok'] else 'FAIL'))
    raise SystemExit(not result['ok'])
