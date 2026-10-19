"""rr-24 source contracts and sampled pixel diagnostics; never GPU acceptance."""
import argparse
from copy import deepcopy
from pathlib import Path

import numpy as np
from PIL import Image

from rr24_build import (PROJECT, CASE, RECIPE, BASELINE, PIECES, polygon,
                        read_json, write_json, source_pixels, residue, visible_layers)
from tools.humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from tools.humanoid_cutout.gates import bindings, matrix
from tools.humanoid_cutout.native_exceptions import load as exceptions, frame_errors
from tools.humanoid_cutout.silhouette_gates import detached_metrics, joint_holes
from maquette_motion.pixels import render
from maquette_motion.material_palette import interior_donors, rules
from rr15_cpu_proof import frame_state

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
    for garment in ('leg_near','leg_far'):
        donors = interior_donors(source_pixels(CASE, parts[garment]), rules(CASE,view))
        palette = set(map(tuple, donors[donors[...,3]>0]))
        for part in parts.values():
            if part['logical_part'] != garment or not part.get('hidden_material'): continue
            image = source_pixels(CASE,part)
            if any(tuple(pixel) not in palette for pixel in image[image[...,3]>0]):
                errors.append('hidden fill must use own skin: '+part['name'])
    return errors


def collar_report(view, layout, samples):
    """Report geometric contact even when front draw order occludes the collar.

    Rear paint exposes the nape rather than a jaw. Its traced lower-head
    boundary is reported separately, without calling it a painted rear mouth.
    """
    recipe = read_json(RECIPE / 'ownership.json')[view]
    masks = []
    for contour, name in [('jaw', 'head'), ('collar', 'torso')]:
        part = next(p for p in layout['parts'] if p['name'] == name)
        image = source_pixels(CASE, part)
        image[~polygon(recipe[contour])] = 0
        x, y, right, bottom = part['bbox']
        masks.append((part, image[y:bottom, x:right]))
    rows, minimum = [], float('inf')
    for pose in samples['samples']:
        if pose['view'] != view or pose['kind'] != 'presented': continue
        jaw, collar = [render(im, sprite_transform(layout, pose, p))[..., 3] > 0 for p, im in masks]
        jy, jx = np.nonzero(jaw); cy, cx = np.nonzero(collar)
        clearance = float(np.sqrt(((jx[:, None] - cx) ** 2 + (jy[:, None] - cy) ** 2).min()))
        minimum = min(minimum, clearance)
        overlaps = int((jaw & collar).sum())
        rows.append({'clip': pose['clip'], 'frame': pose['frame'], 'phase': pose['phase'],
                     'clearance_px': clearance, 'overlap_px': overlaps})
    return {'native_pixels': False, 'scope': 'CPU rigid raster diagnostic, pixel-centre distance',
        'region': 'visible jaw/mouth' if view == 'front' else 'lower head/nape (rear jaw is not painted)',
        'minimum_clearance_px': minimum, 'overlap_frames': [r for r in rows if r['overlap_px']], 'rows': rows}


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
    failures, count = [], 0
    for pose in samples['samples']:
        if pose['view'] != view or pose['kind'] != 'presented': continue
        layers, owners, seams, references, _ = frame_state(model, pose)
        holes = joint_holes(owners > 0, seams, owners, references, pocket_details=True)
        composite = Image.new('RGBA', (512,512))
        for _, image, _ in sorted(layers, key=lambda row: row[0]['z_index']):
            composite.alpha_composite(Image.fromarray(image))
        pixels = np.asarray(composite)
        metric = dict(outside_pixels=0, exposed_outline_pixels=0, dark_slab_blocks=0,
                      outline_outside_pixels=0, **detached_metrics(pixels))
        errors = frame_errors((view, pose['clip'], pose['frame']), metric, holes, approved)
        green = int(residue(pixels).sum())
        if green: errors.append('green residue')
        if errors:
            failures.append({'clip': pose['clip'], 'frame': pose['frame'], 'holes': holes,
                             'green_residue_px': green, 'errors': errors})
        count += 1
        if count % PROOF_PROGRESS_INTERVAL == 0:
            print(f'RR24 CPU {view}: {count} frames; {len(failures)} failing frames', flush=True)
            write_json(RECIPE / f'{view}_raster_progress.json', {'frames': count, 'failures': failures})
    return {'ok': not failures, 'native_pixels': False, 'frames': count, 'failures': failures,
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
        print(f'RR24 {view.upper()} COLLAR: minimum {collar["minimum_clearance_px"]:.6f} px; {len(collar["overlap_frames"])} geometric contact frames (CPU estimate)')
        print(f'RR24 {view.upper()} HEM: {"PASS" if hem["ok"] else "FAIL"} (maximum {hem["maximum_follow_through_px"]:.6f} px; end deltas {hem["end_frame_delta_px"]})')
        failed |= bool(errors) or not hem['ok'] or bool(collar['overlap_frames'])
        if args.raster:
            reports[view]['raster'] = raster_report(view, layout, samples)
            failed |= not reports[view]['raster']['ok']
            raster = reports[view]['raster']
            print(f'RR24 CPU {view.upper()} SEAMS: {"PASS" if raster["ok"] else "FAIL"} ({raster["frames"]} frames; {len(raster["failures"])} failing frames; native acceptance pending)')
    write_json(RECIPE / 'checks.json', {'ok': not failed, 'native_pixels': False, 'views': reports,
        'inputs': samples['inputs']})
    return int(failed)


if __name__ == '__main__': raise SystemExit(main())
