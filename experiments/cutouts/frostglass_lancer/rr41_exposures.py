"""Inventory exact cloak UVs entering the independent vacated leg region.

This is geometry/provenance evidence, not paint synthesis. The resulting repair
list copies only the supplied director texel at each registered UV, including
transparent air. Retained native pixels are never relabelled as a fresh capture.
"""
import argparse
from pathlib import Path
import numpy as np
from rr37_case import CASE
from rr37_proof_case import PROOF_CASE
from rr37_raster import CpuPose
from rr37_uncovered import UncoveredSurface
from rr41_underlay import inputs, CLOAKS
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import mapped, mesh_map
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.native_frames import load_frame
from cutout_pipeline.cases import read_json, write_json, digest


def collect(poses, native=None):
    paint, _ = inputs()
    rows = {}
    manifest = read_json(native/'frames.json') if native else None
    inventory = {}
    if manifest:
        layout=read_json(PROOF_CASE/'layouts/front.json')
        for path in ['layouts/front.json']+[p['file'] for p in layout['parts']]:
            if manifest['inputs'].get(path)!=digest(PROOF_CASE/path):
                raise ValueError('Native exposure inventory needs its original captured source: '+path)
        for row in manifest['pieces']:
            if row['view']=='front': inventory.setdefault((row['clip'],row['frame']),[]).append(row)
    with for_case(CASE):
        model = CpuPose(PROOF_CASE, read_json(PROOF_CASE/'layouts/front.json'))
        gate = UncoveredSurface(PROOF_CASE, model)
        clip = None
        for pose in poses:
            if pose['view']!='front' or pose['kind']!='presented': continue
            if clip != pose['clip']: clip=pose['clip'];print('RR41 EXPOSURE INVENTORY:',clip,flush=True)
            cpu, maps = model.layers(pose)
            layers = cpu if not native else [(dict(gate.parts[r['name']],z_index=r['z_index']),
                np.asarray(load_frame(native/r['file']).convert('RGBA')),None) for r in inventory[clip,pose['frame']]]
            visible = np.full(layers[0][1].shape[:2], '', object)
            for part, image, _ in sorted(layers,key=lambda r:r[0]['z_index']): visible[image[...,3]>0]=part['name']
            area = gate.leg_paint.vacated(pose,layers)
            for part, actual, _ in layers:
                name = part['name']
                if name not in ('hidden_'+n for n in CLOAKS): continue
                exposed = area & (visible==name)
                if not exposed.any(): continue
                source = texture(PROOF_CASE,model.layout,part,gait=clip=='move',clip=clip)
                yy,xx = np.indices(source.shape[:2])
                uv = np.stack((xx+1,yy+1,np.zeros_like(xx),source[...,3]),axis=-1).astype(np.uint8)
                variants = [(mapped(source,maps[name]),mapped(uv,maps[name]))]
                if native:
                    variants = []
                    for packed in (False,True):
                        mapping=mesh_map(model.layout,pose,model.meshes[name],with_ties=True,native_skin=packed)
                        variants += list(zip(mapped(source,mapping,with_ties=True).candidates,mapped(uv,mapping,with_ties=True).candidates))
                certified = gate.leg_paint.sources[name][...,3]>0
                for image, coords in variants:
                    selected = exposed & (coords[...,3]>0) & np.all(actual==image,axis=-1)
                    for y,x in np.argwhere(selected):
                        u,v=coords[y,x,:2].astype(int)-1
                        if certified[v,u]: continue
                        sx,sy=int(u+part['offset'][0]),int(v+part['offset'][1])
                        row=rows.setdefault((name,sx,sy),{'part':name,'uv':[sx,sy],
                            'before':source[v,u].tolist(),'director':paint[sy,sx].tolist(),'frames':set()})
                        row['frames'].add((clip,pose['frame']))
    result=[]
    for key in sorted(rows):
        row=rows[key];row['frames']=[list(f) for f in sorted(row['frames'])];result.append(row)
    return {'native_inventory':bool(native),'retained_capture':bool(native),'current_renderer_proof':False,
        'native_manifest_sha256':digest(native/'frames.json') if native else None,'texels':result}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--poses',type=Path,default=CASE/'proof/logs/samples.json')
    parser.add_argument('--native',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    result=collect(read_json(args.poses)['samples'],args.native)
    result['poses_sha256']=digest(args.poses)
    write_json(args.output,result)
    print('RR41 EXPOSURE INVENTORY: %d source texels'%len(result['texels']))
