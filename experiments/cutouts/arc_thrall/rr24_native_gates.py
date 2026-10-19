"""Extend the full native validator with only the decided Thrall policies."""
from collections import defaultdict

import numpy as np
from PIL import Image

from rr24_build import CASE, read_json, write_json, digest
from rr24_seams import SkirtAirPolicy, head_ownership
from tools.humanoid_cutout.gates import native_errors as shared_native_errors
from tools.humanoid_cutout.anatomy import load
from tools.humanoid_cutout.native_exceptions import load as exceptions, frame_errors, METRIC_RULES, JOINT_HOLE_RULE
from tools.humanoid_cutout.silhouette_gates import posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS


def errors(case,capture,failure_output=None,hole_details=None):
    if case.resolve() != CASE.resolve():
        raise ValueError('rr24 native adapter is scoped to the Thrall case')
    original_pockets = []
    result = shared_native_errors(case,capture,failure_output,original_pockets)
    manifest = read_json(capture/'frames.json')
    samples = read_json(case/'proof/samples.json')
    poses = {(p['view'],p['clip'],p['frame']):p for p in samples['samples'] if p['kind']=='presented'}
    layouts = {view:read_json(case/f'layouts/{view}.json') for view in ('front','rear')}
    policies = {view:SkirtAirPolicy(case,layout) for view,layout in layouts.items()}
    anatomy = load(case); approved = exceptions(case)
    original = {(p['view'],p['clip'],p['frame']):p['pockets'] for p in original_pockets}
    grouped = {}
    for field in ('pieces','joint_seams','rest_holes'):
        grouped[field] = defaultdict(list)
        for row in manifest[field]: grouped[field][row['view'],row['clip'],row['frame']].append(row)
    air, contacts, failures = [], [], []
    for key,rows in grouped['pieces'].items():
        view,clip,frame = key
        if key not in poses: continue  # Full validator already records missing poses.
        layout,pose = layouts[view],poses[key]
        layers,allowed = [],{}
        for row in rows:
            if any(name not in row or digest(capture/row[field])!=row[name]
                   for field,name in [('file','sha256'),('checks','checks_sha256')]):
                result.append(str(key)+': missing/changed native policy evidence hashes')
            part = next(p for p in layout['parts'] if p['name']==row['name'])
            image = np.asarray(Image.open(capture/row['file']).convert('RGBA'))
            checks = np.asarray(Image.open(capture/row['checks']).convert('RGBA'))
            layers.append((part,image,checks)); allowed[part['name']] = checks[...,0] > 0
        if len(layers)!=len(layout['parts']): continue
        ownership = head_ownership(layers)
        if ownership['contact_pixels']: contacts.append(dict(view=view,clip=clip,frame=frame,**ownership))
        if not ownership['ok']: result.append(str(key)+': collar covers rendered head')
        occupied = np.logical_or.reduce([image[...,3]>0 for _,image,_ in layers])
        owners = posed_owners(layers,layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'],anatomy['ownership'])
        references = [np.asarray(Image.open(capture/r['file']).convert('RGBA'))[...,3]>0
                      for r in grouped['rest_holes'].get(key,[])]
        seam = np.zeros_like(occupied)
        for row in grouped['joint_seams'].get(key,[]):
            seam |= np.asarray(Image.open(capture/row['file']).convert('RGBA'))[...,3] > 0
        classified = policies[view].report(occupied,owners,seam,references,pose,{},allowed)
        air.extend(dict(view=view,clip=clip,frame=frame,**p) for p in classified['air_pockets'])
        zero_metric = dict.fromkeys(METRIC_RULES,0)
        rejected = frame_errors(key,zero_metric,classified['failures'],approved)
        air_signatures = {(tuple(p['bbox']),p['pixel_count']) for p in classified['air_pockets']}
        unapproved = [p for p in original.get(key,[]) if frame_errors(key,zero_metric,[p],approved)]
        # Remove only the old strict seam error whose complete observed
        # pocket set has now passed this case policy. Every other native
        # failure and every painted/tuck/joint pocket remains a failure.
        if unapproved and not rejected and all((tuple(p['bbox']),p['pixel_count']) in air_signatures for p in unapproved):
            result = [e for e in result if e != str(key)+': '+JOINT_HOLE_RULE]
        result.extend(e for e in rejected if e not in result)
        if rejected:
            record = dict(view=view,clip=clip,frame=frame,pockets=classified['failures'])
            failures.append(record)
            if hole_details is not None: hole_details.append(record)
    write_json(capture/'rr24_policy_report.json',{'ok':not result,'native_pixels':True,
        'air_pockets':air,'contact_frames':contacts,'failures':failures,'errors':result,
        'inputs':manifest['inputs']})
    return result
