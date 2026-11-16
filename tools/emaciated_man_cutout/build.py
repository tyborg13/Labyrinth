#!/usr/bin/env python3
"""Compile only the supplied emac-01 geometry; preserve all director inputs."""
from pathlib import Path
import json
import sys
import hashlib
import shutil
import argparse
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tools'))
from spec.art_identity.maquettes.emaciated_man_proof import compile_spec
from maquette_cutout import build, projected, display_palette
from spec.art_identity.maquettes.geometry import build_meshes
from cutout_pipeline.cases import write_json, read_json, baseline

CASE = ROOT / 'experiments/cutouts/emaciated_man/emac02'
INPUTS = ROOT / 'experiments/cutouts/emaciated_man/emac02_inputs'
JOB = ROOT / 'spec/art_identity/jobs/emaciated_man/mq_front'
PROOF_DEFAULTS = {'mesh_grid': [2, 1], 'clip_frames': 224}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case', type=Path, default=CASE)
    a = p.parse_args()
    INPUTS.mkdir(parents=True, exist_ok=True)
    spec = compile_spec()
    spec['facings'] = ['front']
    write_json(INPUTS / 'spec.json', spec)
    config = Path('/Applications/Blender.app/Contents/Resources/5.2/datafiles/colormanagement/config.ocio')
    palette = display_palette(spec, config)
    write_json(INPUTS / 'palette.json', palette)
    joints = {n: {'joint': j, 'parent': parent} for n,j,parent in [
        ('root','root',None), ('robe_torso','root','root'), ('head_hood','neck','root'),
        ('near_upper_arm','shoulder_near','root'), ('near_forearm','elbow_near','root'),
        ('near_hand','wrist_near','root'), ('far_upper_arm','shoulder_far','root'),
        ('far_forearm_hand','elbow_far','far_upper_arm'), ('legs','root','root'), ('ember_sack','sack_base','root') ]}
    # Far hand is part of the forearm paint. Its rigid support is the supplied
    # hand ellipsoid; its wrist comes from that ellipsoid's owning limb endpoint.
    hand_shape = next(s for s in spec['shapes'] if s['part']=='far_forearm_hand' and s['type']=='ellipsoid')
    fore_shape = next(s for s in spec['shapes'] if s['part']=='far_forearm_hand' and s['type']=='limb')
    spec['joints']['far_hand_support'] = hand_shape['c']
    joints['far_hand_support'] = {'joint':'far_hand_support','parent':'root'}
    # This helper joint is derived from protected geometry. Keep cached joint
    # inventory untouched: supply it to the builder as a derived render closure.
    renders = INPUTS / 'renders'; renders.mkdir(exist_ok=True)
    for file in JOB.glob('front_*.png'):
        if file.stem in ['front_parts','front_clay'] or file.stem.startswith('front_solo_'):
            shutil.copyfile(file, renders / file.name)
    projected_joints=json.loads((JOB/'joints_px.json').read_text())
    projected_joints['front']['far_hand_support']=projected(spec, hand_shape['c'], 'front')
    write_json(renders/'joints_px.json',projected_joints)
    write_json(INPUTS/'spec.json', spec)
    factor=194/135
    pivot=np.array([128,254])
    transform=lambda p: (np.array(p)/4-pivot)*factor+pivot
    wrist=transform(projected(spec,fore_shape['b'],'front'))
    elbow=transform(projected_joints['front']['elbow_far'])
    recipe = {'character_id':'emaciated_man', 'joints':joints,
        'parts':{n:n for n in spec['labels']}, 'motion':'motion.gd',
        'clips':{'idle':{'frames':PROOF_DEFAULTS['clip_frames'],'duration':3.36,'loop':True,'stepped_pose':True,'preview_cycles':1}},
        'rigid_bones':['legs','ember_sack'], 'contact_feet':[],
        'copy_files':[{'from':'../../../..//scripts/emaciated_man_cutout/motion.gd','to':'motion.gd'}],
        'materials':{n: ('skin' if n in ['near_hand','near_forearm','near_upper_arm','far_upper_arm','far_forearm_hand'] else 'approved brown cloth') for n in spec['labels']},
        'ownership_regions':{'front':[
          {'part':'head_hood','replace_owners':['ember_sack'],'polygon':[[0,0],[254,0],[254,133],[0,133]],'reason':'Round 3 rigid groups: maquette edge-label islands on the painted hood belong to the upper body, not the static sack.'},
          {'part':'robe_torso','replace_owners':['ember_sack'],'polygon':[[0,134],[254,134],[254,207],[0,207]],'reason':'Round 3 rigid groups: isolated sack-label islands above the painted sack neck follow the upper body.'},
          {'part':'ember_sack','replace_owners':['robe_torso','near_forearm'],
          'polygon':[((np.array(p)-pivot)*factor+pivot).tolist() for p in [[181,222],[196,222],[201,229],[207,240],[209,250],[202,254],[175,254],[163,247],[163,239],[173,227]]],
          'reason':'Director round 1: painted sack contour below the planted hand; this cloth is sack paint, not the breathing torso. Trace from approved processed take.'}]},
        'maquette_registration':{'front':{'scale':[factor/4,factor/4],'offset':((1-factor)*pivot).tolist(),
          'trace':{'basis':'Director round 3: original maquette / 4, then 194/135 about (128,254); no silhouette fitting','reference_bbox':[70,120,207,254]}}},
        'cloth':{'far_forearm_hand':{'bones':['far_forearm_hand','far_hand_support'],
          'bands':[{'center':((elbow+wrist)/2).tolist(),'axis':(wrist-elbow).tolist(),'width':float(np.linalg.norm(wrist-elbow))}]}},
        'proof_defaults':PROOF_DEFAULTS}
    # copy_files paths resolve from INPUTS; motion remains an exact source copy.
    recipe['copy_files'][0]['from']='../../../../scripts/emaciated_man_cutout/motion.gd'
    write_json(INPUTS/'rig.json',recipe)
    result = build(argparse.Namespace(case=a.case,spec=INPUTS/'spec.json',rig_recipe=INPUTS/'rig.json',front_job=JOB,rear_job=None,front_raw=None,rear_raw=None,renders=renders,palette=INPUTS/'palette.json',color_config=None,view_transforms=None,blender='',resume_scaffold=False,allow_incomplete_renders=False,task_id='emac-02'))
    config=read_json(a.case/'cutout.json')
    for relative in {config['layouts']['front'],'layouts/front.json'}:
        path=a.case/relative; layout=read_json(path)
        layout['glow_min_saturation']=0.75  # director 2026-11-15: selects exactly both eyes and the sack tear
        layout['glow_overlays']=[{'part':'head_hood','channel':'eyes'},{'part':'ember_sack','channel':'sack'}]
        # Head width means the rounded hood shell, excluding its back drape.
        # Use the supplied shell primitive, not the whole ownership crop.
        hood_shape=[s for s in spec['shapes'] if s['part']=='head_hood'][1]
        hood_mesh=build_meshes({**spec,'shapes':[hood_shape]})['head_hood']
        hood_xy=np.array([transform(projected(spec,p,'front')) for p in hood_mesh.vertices])
        layout['portrait_head_width']=float(np.ptp(hood_xy[:,0]))
        layout['idle_groups']={'upper':{'bones':['robe_torso','head_hood','near_upper_arm','near_forearm','near_hand','far_upper_arm','far_forearm_hand','far_hand_support']},'lower':{'bones':['legs','ember_sack']}}
        write_json(path,layout)
    write_json(a.case/'cutout.json',config)
    baseline(a.case)
    result['complete']=False
    result['pending_design']=config['design_placeholders']
    print(json.dumps(result,indent=2))


if __name__=='__main__': main()
