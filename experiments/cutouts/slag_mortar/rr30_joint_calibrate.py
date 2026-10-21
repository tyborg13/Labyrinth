"""Cut actual off-joint cover texels from source geometry over the whole sweep.

Only static source alpha changes. This is not a frame mask or gate exception:
the removed texels never render in any clip, including the flagged lob frames.
"""
import argparse
import hashlib
import json
import numpy as np
from PIL import Image
from rr30_case import CASE
from rr30_cpu import CpuPose as CoveragePose
from rr30_joint_gate import JointSurfaceGate
from rr30_joint_geometry import source_materials
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings
from rr30_cpu import sprite_transform
from maquette_motion import pixels
from rr30_joint_storage import read_evidence,write_calibration,compact_calibration

CUTS=CASE.parent/'rr30_joint_cover_cuts.json'


def basis(visible,joints):
    return dict(visible={n:hashlib.sha256(image.tobytes()).hexdigest() for n,image in visible.items()},
                joints=hashlib.sha256(json.dumps(joints,sort_keys=True).encode()).hexdigest(),
                director_motion=digest(CASE/'director_motion.json'))


def run(samples,extend=False):
    if samples['inputs']!=bindings(CASE): raise ValueError('Refresh samples before cover calibration')
    previous=read_json(CUTS) if extend and CUTS.exists() else {}
    previous_evidence=read_evidence(CUTS,previous) if previous else {}
    result={}
    storage_path=CASE.parent/'rr30_storage_bounds.json'
    storage=read_json(storage_path) if storage_path.exists() else {}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');model=CoveragePose(CASE,layout)
        gate=JointSurfaceGate(CASE,layout)
        cuts={name:set(map(tuple,points)) for name,points in previous.get(view,{}).get('cuts',{}).items()}
        evidence=list(previous_evidence.get(view,[]))
        storage.setdefault(view,{})
        for part in layout['parts']:
            if part['hidden_material']:storage[view].setdefault(part['name'],part['bbox'])
        rows=[r for r in samples['samples'] if r['view']==view and r['kind']=='presented']
        for index,pose in enumerate(rows):
            layers,_=model.layers(pose);report=gate.frame(pose,layers,potential_covers=True)
            for error in report['cover_errors']:
                name=error['piece'];part=next(p for p in layout['parts'] if p['name']==name)
                from humanoid_cutout.gait_continuations import active_recipe,texture
                source=model.image(part['file'])
                if active_recipe(layout,name,gait=pose['clip']=='move',clip=pose['clip']) is not None:
                    source=texture(CASE,layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                yy,xx=np.indices(source.shape[:2])
                uv=np.stack((xx,yy,np.ones_like(xx),source[...,3]),axis=2).astype('uint8')
                shown=pixels.render(uv,sprite_transform(layout,pose,part))
                points=np.asarray(error['destination_pixels']);uvs=shown[points[:,1],points[:,0],:2].astype(int)+part['offset']
                cuts.setdefault(name,set()).update(map(tuple,uvs.tolist()))
                evidence.append(dict(clip=pose['clip'],frame=pose['frame'],piece=name,
                    maximum_distance_px=error['maximum_distance_px'],source_texels=uvs.tolist()))
            if (index+1)%50==0: print('RR30 %s COVER CALIBRATION: %d/%d frames'%(view.upper(),index+1,len(rows)),flush=True)
        visible,_=source_materials(CASE,layout)
        result[view]=dict(basis=basis(visible,layout['joints']),frames=len(rows),
            cuts={name:sorted(map(list,points)) for name,points in cuts.items()},evidence=evidence)
        print('RR30 %s STATIC COVER CUTS: %d source texels'%(view.upper(),sum(len(points) for points in cuts.values())),flush=True)
    compact=write_calibration(CUTS,result)
    write_json(storage_path,storage)
    return compact


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--samples')
    source.add_argument('--compact',action='store_true',help='Repackage existing cuts/evidence without changing calibration')
    parser.add_argument('--extend',action='store_true')
    args=parser.parse_args()
    if args.extend and not args.samples: parser.error('--extend requires --samples')
    if args.compact:
        result=compact_calibration(CUTS)
        print('RR30 COVER CALIBRATION STORAGE: PASS (compact cuts; %d evidence rows in %s)'%
              (sum(result['full_evidence']['rows'].values()),result['full_evidence']['file']))
    else:
        run(read_json(__import__('pathlib').Path(args.samples)),args.extend)
