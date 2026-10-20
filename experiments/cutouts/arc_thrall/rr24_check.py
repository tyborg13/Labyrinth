"""rr-24 source contracts and sampled pixel diagnostics; never GPU acceptance."""
import argparse
from copy import deepcopy
from pathlib import Path

import numpy as np
from PIL import Image

from rr24_build import (PROJECT, CASE, RECIPE, BASELINE, PIECES, polygon,
                        read_json, write_json, source_pixels, residue, visible_layers, clean_residue)
from tools.humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from tools.humanoid_cutout.gates import bindings, matrix
from tools.humanoid_cutout.native_exceptions import load as exceptions, frame_errors
from tools.humanoid_cutout.silhouette_gates import detached_metrics, joint_holes
from maquette_motion.pixels import render
from maquette_motion.material_palette import interior_donors, rules
from rr15_cpu_proof import frame_state
from tools.humanoid_cutout.anatomy import load as load_anatomy
from rr24_seams import head_ownership, SkirtAirPolicy
from tools.humanoid_cutout.silhouette_gates import posed_owners
from rr24_materials import donor_palettes, foreign_pixels, exposed_provenance

PROOF_PROGRESS_INTERVAL = 50
FLOAT_TOLERANCE_PX = 0.0001


def source_errors(view, layout):
    errors = []
    paint = np.asarray(Image.open(CASE / layout['raw_rest_source']).convert('RGBA'))
    expected = visible_layers(view, paint)
    composite = np.zeros_like(paint)
    ownership_count = np.zeros(paint.shape[:2], dtype=int)
    for name in PIECES:
        raw = np.asarray(Image.open(RECIPE / 'raw' / view / (name + '.png')).convert('RGBA'))
        if not np.array_equal(raw, expected[name]): errors.append('raw source ownership: ' + name)
        selected = raw[..., 3] > 0
        composite[selected] = raw[selected]
        ownership_count[selected] += 1
    if not np.array_equal(composite, paint): errors.append('raw rest differs from mq7b')
    if np.any(ownership_count > 1): errors.append('overlapping raw ownership')
    parts = {p['name']: p for p in layout['parts']}
    if parts['torso']['bone'] != 'torso' or any(m['name'] == 'torso' for m in layout['joint_meshes']):
        errors.append('collar must remain rigid torso')
    if parts['head']['z_index'] <= parts['torso']['z_index']:
        errors.append('head must draw above collar')
    if parts['loincloth']['bone'] != 'pelvis': errors.append('skirt attachment differs')
    if parts['loincloth']['z_index'] <= max(parts[n]['z_index'] for n in ('leg_near', 'leg_far')):
        errors.append('skirt must cover both thighs')
    mesh = next(m for m in layout['joint_meshes'] if m['name'] == 'loincloth')
    if set(mesh['weights']) != {'pelvis', 'loincloth_tip'}: errors.append('skirt chain differs')
    frozen = read_json(BASELINE / f'layouts/{view}.json')
    if layout['joints'] != frozen['joints']: errors.append('protected skeletal rest changed')
    if (CASE / 'compiled_motion.json').read_bytes() != (BASELINE / 'compiled_motion.json').read_bytes():
        errors.append('protected compiled motion changed')
    for part in parts.values():
        if residue(source_pixels(CASE, part)).any(): errors.append('green residue: ' + part['name'])
    palettes = donor_palettes({name:clean_residue(image)[0] for name,image in expected.items()},rules(CASE,view))
    for part in parts.values():
        if not part.get('hidden_material'): continue
        if foreign_pixels(source_pixels(CASE,part),palettes[part['logical_part']]).any():
            if part['logical_part'] in ('leg_near','leg_far'):
                errors.append('hidden fill must use own skin: '+part['name'])
            else:
                errors.append('hidden fill must use own mq7b texels: '+part['name'])
    return errors


def collar_report(view, layout, samples):
    """Gate ownership of rendered surfaces; report allowed head/band contact."""
    parts = [p for p in layout['parts'] if p['name'] in ('head','torso')]
    sources = {p['name']:np.asarray(Image.open(CASE/p['file']).convert('RGBA')) for p in parts}
    rows = []
    for pose in samples['samples']:
        if pose['view'] != view or pose['kind'] != 'presented': continue
        layers = [(p,render(sources[p['name']],sprite_transform(layout,pose,p)),None) for p in parts]
        rows.append(dict(clip=pose['clip'],frame=pose['frame'],phase=pose['phase'],**head_ownership(layers)))
    return {'ok':all(r['ok'] for r in rows),'native_pixels':False,
        'scope':'CPU rendered ownership of visible head versus whole torso; contact allowed',
        'contact_frames':[r for r in rows if r['contact_pixels']],
        'failures':[r for r in rows if not r['ok']],'rows':rows}


def hem_report(view, layout, samples):
    attachment = np.asarray(layout['joints']['pelvis']['position'])
    tip = np.asarray(layout['joints']['loincloth_tip']['position'])
    delta = tip - attachment
    maximum, clips = 0., {}
    for pose in samples['samples']:
        if pose['view'] != view or pose['kind'] != 'presented': continue
        pelvis = matrix(pose['bones']['pelvis']['global'])
        expected = pelvis[:2, :2] @ delta + pelvis[:2, 2]
        actual = np.asarray(pose['bones']['loincloth_tip']['global'][4:])
        distance = float(np.linalg.norm(actual - expected))
        maximum = max(maximum, distance)
        clips.setdefault(pose['clip'], []).append((pose['frame'], actual - expected))
    settled = {}
    for clip, rows in clips.items():
        # Terminal death settles at its authored displaced endpoint; recovery
        # clips return to zero. Two final samples must agree to whole-pixel
        # presentation precision after subtracting the moving pelvis frame.
        settled[clip] = float(np.linalg.norm(rows[-1][1] - rows[-2][1]))
    return {'maximum_follow_through_px': maximum, 'end_frame_delta_px': settled,
        'ok': maximum <= 4 + FLOAT_TOLERANCE_PX and all(d <= FLOAT_TOLERANCE_PX for d in settled.values())}


def raster_report(view, layout, samples):
    model = CpuPose(CASE, deepcopy(layout))
    approved = exceptions(CASE)
    policy = SkirtAirPolicy(CASE,layout)
    paint = np.asarray(Image.open(CASE/layout['raw_rest_source']).convert('RGBA'))
    palettes = donor_palettes({n:clean_residue(im)[0] for n,im in visible_layers(view,paint).items()},rules(CASE,view))
    failures, air, count = [], [], 0
    provenance = {'exposed_pixels':0,'foreign_pixels':0,'failures':[]}
    for pose in samples['samples']:
        if pose['view'] != view or pose['kind'] != 'presented': continue
        layers,maps = model.layers(pose)
        owners = posed_owners(layers,layout['parts'],pose['bones'],128,load_anatomy(CASE)['ownership'])
        seams = np.logical_or.reduce(model.masks(pose,layout['proof_joint_seams'],maps))
        references = model.masks(pose,layout['proof_rest_holes'],maps)
        classified = policy.report(owners>0,owners,seams,references,pose,maps)
        holes = classified['failures']
        air.extend(dict(clip=pose['clip'],frame=pose['frame'],**pocket) for pocket in classified['air_pockets'])
        composite = Image.new('RGBA', (512,512))
        for _, image, _ in sorted(layers, key=lambda row: row[0]['z_index']):
            composite.alpha_composite(Image.fromarray(image))
        pixels = np.asarray(composite)
        metric = dict(outside_pixels=0, exposed_outline_pixels=0, dark_slab_blocks=0,
                      outline_outside_pixels=0, **detached_metrics(pixels))
        errors = frame_errors((view, pose['clip'], pose['frame']), metric, holes, approved)
        exposed = exposed_provenance(layers,palettes)
        provenance['exposed_pixels'] += sum(row['exposed_pixels'] for row in exposed)
        foreign = sum(row['foreign_pixels'] for row in exposed)
        provenance['foreign_pixels'] += foreign
        if foreign:
            errors.append('foreign exposed hidden colour')
            provenance['failures'].append({'clip':pose['clip'],'frame':pose['frame'],'pieces':exposed})
        green = int(residue(pixels).sum())
        if green: errors.append('green residue')
        if errors:
            failures.append({'clip': pose['clip'], 'frame': pose['frame'], 'holes': holes,
                             'green_residue_px': green, 'errors': errors})
        count += 1
        if count % PROOF_PROGRESS_INTERVAL == 0:
            print(f'RR24 CPU {view}: {count} frames; {len(failures)} failing frames', flush=True)
            write_json(RECIPE / f'{view}_raster_progress.json', {'frames': count, 'failures': failures})
    return {'ok': not failures, 'native_pixels': False, 'frames': count, 'failures': failures, 'air_pockets':air,
            'hidden_provenance':provenance,
            'scope': 'CPU estimate only; director native gates remain mandatory'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raster', action='store_true')
    args = parser.parse_args()
    samples = read_json(CASE / 'proof/samples.json')
    if samples['inputs'] != bindings(CASE) or not samples['ok']:
        raise ValueError('Refresh headless samples before rr24 checks')
    reports = {}
    failed = False
    for view in ('front', 'rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        errors = source_errors(view, layout)
        collar = collar_report(view, layout, samples)
        hem = hem_report(view, layout, samples)
        reports[view] = {'source_errors': errors, 'collar': collar, 'hem': hem}
        print(f'RR24 {view.upper()} SOURCE/RESIDUE: {"FAIL" if errors else "PASS"} ({len(errors)} errors)')
        print(f'RR24 {view.upper()} COLLAR OWNERSHIP: {"PASS" if collar["ok"] else "FAIL"} ({len(collar["contact_frames"])} contact frames; {len(collar["failures"])} covered-head frames)')
        print(f'RR24 {view.upper()} HEM: {"PASS" if hem["ok"] else "FAIL"} (maximum {hem["maximum_follow_through_px"]:.6f} px; end deltas {hem["end_frame_delta_px"]})')
        failed |= bool(errors) or not hem['ok'] or not collar['ok']
        if args.raster:
            reports[view]['raster'] = raster_report(view, layout, samples)
            failed |= not reports[view]['raster']['ok']
            raster = reports[view]['raster']
            print(f'RR24 CPU {view.upper()} SEAMS: {"PASS" if raster["ok"] else "FAIL"} ({raster["frames"]} frames; {len(raster["failures"])} failing frames; native acceptance pending)')
    if bindings(CASE)!=samples['inputs']:
        raise ValueError('Inputs changed during Thrall checks; discard this run')
    write_json(RECIPE / 'checks.json', {'ok': not failed, 'native_pixels': False, 'views': reports,
        'inputs': samples['inputs']})
    return int(failed)


if __name__ == '__main__': raise SystemExit(main())
