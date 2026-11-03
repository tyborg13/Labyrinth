"""Strict all-frame construction check, using the actual runtime's sampled poses.

Software raster is explicitly not a GPU seal. Unlike the old 54-pose diagnostic,
this checks production textures and the same seam/component policies as native.
"""
import argparse
from collections import Counter
from pathlib import Path
import numpy as np
from PIL import Image
from rr37_case import CASE, ASSETS
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.anatomy import load
from humanoid_cutout.held_release import ComponentPolicy
from rr37_raster import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import clean_metrics
from humanoid_cutout.silhouette_gates import joint_holes, posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import components


def state(model, pose):
    layers, maps = model.layers(pose)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'],
                          PROOF_DEFAULTS['source_offset'], load(CASE)['ownership'])
    records = model.layout.get('proof_joint_seams', [])
    seams = np.logical_or.reduce(model.masks(pose, records, maps)) if records else np.zeros(owners.shape,bool)
    refs = model.masks(pose, model.layout.get('proof_rest_holes',[]), maps)
    pockets = joint_holes(owners>0, seams, owners, refs, pocket_details=True)
    return layers, maps, owners, pockets


def report(samples, production=False, save=True, views=('front','rear'), save_summary=True):
    if production and samples.get('paint_scope')!='production':
        raise ValueError('Production frames require fresh poses from samples.gd --production')
    result={}
    with for_case(CASE):
        for view in views:
            root=CASE
            if production:
                from rr37_proof_case import PROOF_CASE
                root=PROOF_CASE
            layout=read_json(root/f'layouts/{view}.json')
            model=CpuPose(root,layout)
            from rr37_uncovered import UncoveredSurface
            uncovered=UncoveredSurface(root,model)
            failures=[];count=0;released_frames=0;death_frames=0;edge_pixels=0
            uncovered_by_clip={}
            rest=np.asarray(Image.open(root/layout['rest_source']).convert('RGBA'))
            policy=ComponentPolicy(load(root),read_json(root/'compiled_motion.json'),layout,
                                   len(components(rest[...,3]>0,8)[1]))
            for pose in samples['samples']:
                if pose['view']!=view or pose['kind']!='presented': continue
                layers,maps,owners,pockets=state(model,pose)
                from rr37_covered import empty_pixels
                exposed=empty_pixels(view,layers)
                component=policy.report(owners>0,layers,pose['clip'],pose['phase'])
                released_frames+=bool(component['released_components'])
                death_frames+=pose['clip']=='death'
                metrics=clean_metrics(layers)
                defects={k:metrics[k] for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks') if metrics[k]}
                alpha=owners>0
                edge=int(alpha[0].sum()+alpha[-1].sum()+alpha[:,0].sum()+alpha[:,-1].sum())
                edge_pixels+=edge
                if edge: defects['action_canvas_edge_pixels']=edge
                surface_metrics=uncovered.measure(pose,layers,maps)
                totals=uncovered_by_clip.setdefault(pose['clip'],dict.fromkeys(surface_metrics,0))
                for key,value in surface_metrics.items(): totals[key]+=value
                defects.update({k:n for k,n in surface_metrics.items() if n})
                if exposed: defects['paint_on_empty_rear_piece']=exposed
                if component['errors']: defects['components']=component['errors']
                count+=1
                if pockets or defects:
                    failures.append({'clip':pose['clip'],'frame':pose['frame'],'phase':pose['phase'],'pockets':pockets,'metrics':defects})
                    if save:
                        image=Image.new('RGBA',(PROOF_DEFAULTS['canvas_size'],)*2)
                        for _,pixels,_ in sorted(layers,key=lambda r:r[0]['z_index']): image.alpha_composite(Image.fromarray(pixels))
                        path=CASE/f'proof/logs/headless_frames/{view}_{pose["clip"]}_{pose["frame"]:04d}.png'
                        path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
            result[view]={'ok':not failures,'frames':count,'failures':failures,
                          'action_canvas_edge_pixels':edge_pixels,
                          'death_frames':death_frames,'released_component_frames':released_frames,
                          'uncovered_totals_by_clip':uncovered_by_clip,'native_pixels':False}
            print(f'RR37 {view.upper()} {"PRODUCTION" if production else "SOURCE"} FRAMES: {"FAIL" if failures else "PASS"} ({count} frames; {len(failures)} failures; software raster, native runtime poses)',flush=True)
            for clip in ('cast','lunge','guard','jab','pin'):
                if clip in uncovered_by_clip:
                    print(f'RR39 {view.upper()} {clip.upper()} UNCOVERED: {uncovered_by_clip[clip]} (headless native-equivalent)',flush=True)
            if failures: print(f'RR37 {view.upper()} FAILURE CLIPS: {dict(sorted(Counter(f["clip"] for f in failures).items()))}',flush=True)
    if save and save_summary: write_json(CASE/f'proof/logs/{"production" if production else "source"}_frames.json',result)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--production',action='store_true');p.add_argument('--samples',type=Path);a=p.parse_args()
    if a.samples is None: a.samples=CASE/('proof/logs/production_runtime_samples.json' if a.production else 'proof/logs/samples.json')
    r=report(read_json(a.samples),a.production);raise SystemExit(any(not v['ok'] for v in r.values()))
