"""mq-14 acceptance from native masks; no painting segmentation is invented."""
from copy import deepcopy
import csv
import json
from pathlib import Path

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.fit_delivery import registered_parts, overlay_parts
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.fitting import keyed_mask, measure
from spec.art_identity.maquettes.raster import camera, project
from tests.test_maquette_rear_turn import observations
from .recipe import FIGURE

PROJECT = FIGURE.parents[3]
PROOF_DEFAULTS = {'overlay_opacity': .4, 'shoulder_tolerance_px': 10, 'numerical_epsilon': 1e-10}


def fit_views(spec, capture, output):
    measured = json.loads((FIGURE / 'mq14/measurements.json').read_text())
    views, overlays = {}, {}
    for view in ('front', 'rear'):
        path = PROJECT / ('spec/art_identity/jobs/frostglass_lancer/mq4_' + view + '/processed.png')
        image = Image.open(path).convert('RGBA')
        raster = load_render(spec, capture, view)
        working = deepcopy(spec)
        working['fit']['source_frame'] = measured['source_frame'][view]
        diagnostic, _ = measure(working, image, raster=raster)
        sensitivity = deepcopy(working)
        sensitivity['fit']['source_frame'] = measured['geometry_source_frame'][view]
        centroid_fit, _ = measure(sensitivity, image, raster=raster)
        coverage = part_coverage(spec, raster, Image.open(capture / (view + '_parts.png')).convert('RGBA'))
        for part, row in coverage.items():
            solo = Image.open(capture / (view + '_solo_' + part + '.png')).convert('RGBA')
            registered = np.asarray(registered_parts(solo, diagnostic, image.size))[..., 3] >= 128
            row['painting_alpha_coverage'] = float((registered & keyed_mask(image)).sum() / max(1, registered.sum()))
            row['explicit_occlusion'] = measured.get('source_occlusions', {}).get(view, {}).get(part)
            if not row['pure_owner_pixels']:
                owners, counts = np.unique(raster.owners[raster.masks[part]], return_counts=True)
                row['native_occluding_owner_pixels'] = {
                    raster.names[int(i)] if i >= 0 else 'background': int(n) for i, n in zip(owners, counts)}
        missing = [part for part, row in coverage.items() if not row['solo_pixels'] or row['clipped_at_canvas'] or
                   (not row['pure_owner_pixels'] and not row['explicit_occlusion'])]
        views[view] = {'iou': diagnostic['iou'], 'iou_min': measured['fit_iou_min'][view],
            'passed': diagnostic['iou'] >= measured['fit_iou_min'][view] and not missing,
            'source': str(path.relative_to(PROJECT)), 'source_sha256': sha(path),
            'source_frame': diagnostic['source_frame'], 'maquette_frame': diagnostic['maquette_frame'],
            'normalisation': diagnostic['normalisation'], 'per_part_coverage': coverage,
            'missing_or_clipped_parts': missing,
            'report_only': {'median_band_error': diagnostic['median_band_error'],
                            'max_band_error': diagnostic['max_band_error'], 'landmarks': diagnostic['landmarks'],
                            'alpha_centroid_registration_iou': centroid_fit['iou'],
                            'alpha_centroid_source_frame': measured['geometry_source_frame'][view]}}
        parts = registered_parts(Image.open(capture / (view + '_parts.png')).convert('RGBA'), diagnostic, image.size)
        overlays[view] = overlay_parts(image, parts, PROOF_DEFAULTS['overlay_opacity'])
        overlays[view].save(output / (view + '_fit_overlay.png'))
    result = {'passed': all(v['passed'] for v in views.values()), 'spec_hash': digest(spec), 'views': views,
        'coverage_method': 'Native unoccluded solos and pure depth-tested part colours; registered coverage uses whole painting alpha. No part segmentation was supplied.',
        'acceptance': 'mq-14 IoU thresholds and per-part presence/explicit occlusion. Older r3 width and landmark thresholds are report-only.'}
    result['registration_authority'] = measured['registration_authority']
    write(output / 'fit_report.json', result)
    pair = Image.new('RGBA', (512, 256))
    for index, view in enumerate(('front', 'rear')):
        pair.paste(overlays[view], (index*256, 0))
    pair.save(output / 'fit_overlay.png')
    rows = ['| View | IoU | Minimum | Missing/clipped |', '|---|---:|---:|---|']
    for view, value in views.items():
        rows.append(f'| {view} | {value["iou"]:.9f} | {value["iou_min"]:.2f} | {", ".join(value["missing_or_clipped_parts"]) or "none"} |')
    (output / 'fit_table.md').write_text('\n'.join(rows)+'\n')
    with (output / 'per_part_coverage.csv').open('w', newline='') as stream:
        writer = csv.writer(stream, lineterminator='\n')
        fields = ['visible_pixels', 'solo_pixels', 'visible_fraction_of_solo', 'pure_owner_pixels',
                  'painting_alpha_coverage', 'clipped_at_canvas', 'explicit_occlusion']
        writer.writerow(['view', 'part', *fields])
        for view, value in views.items():
            for part, row in value['per_part_coverage'].items():
                writer.writerow([view, part, *(row[k] for k in fields)])
    print('MQ14_FIT: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' +
          '; '.join(v+'_iou='+format(r['iou'], '.9f') for v, r in views.items()), flush=True)
    return result


def shoulder_values(spec, joints=None):
    near, far = ([np.array(joints['front']['shoulder_'+side]) for side in ('near', 'far')] if joints else
                 project(spec, [spec['joints'][j] for j in ('shoulder_near', 'shoulder_far')])[:, :2])
    return {'near_px': near.tolist(), 'far_px': far.tolist(), 'far_above_near_px': float(near[1]-far[1]),
            'expected_px': float(.15*abs(near[0]-far[0])),
            'level_in_3d': abs(spec['joints']['shoulder_near'][2]-spec['joints']['shoulder_far'][2]) <= PROOF_DEFAULTS['numerical_epsilon']}


def proof(root, spec):
    root = Path(root)
    output, capture = root / 'review', root / 'capture'
    output.mkdir(parents=True, exist_ok=True)
    fit = fit_views(spec, capture, output)
    original = board_spec(json.loads((FIGURE / 'spec_r3.json').read_text()))
    common = deepcopy(original)
    for key in ('ortho_scale', 'target'):
        common[key] = spec[key]
    after = shoulder_values(spec, json.loads((capture / 'joints_px.json').read_text()))
    shoulders = {'before_r4_provenance_camera': shoulder_values(original), 'before_common_proof_camera': shoulder_values(common),
                 'after_delivery_camera': after, 'tolerance_px': PROOF_DEFAULTS['shoulder_tolerance_px']}
    turn = observations(capture, labels=spec['labels'])
    rotations = {v: camera(spec, v)[0][:3, :3] for v in ('front', 'rear')}
    true_rotation = np.allclose(rotations['rear'], np.diag([-1., -1., 1.]) @ rotations['front']) and all(
        abs(np.linalg.det(m)-1) < PROOF_DEFAULTS['numerical_epsilon'] for m in rotations.values())
    depth_turn = all(row['lower_foot_right'] and row['body_side_pixels_over_torso']['near' if view == 'front' else 'far'] >
                     row['body_side_pixels_over_torso']['far' if view == 'front' else 'near'] for view, row in turn.items())
    native = json.loads((root / 'native_audit.json').read_text())
    exact = json.loads((root / 'exact_native_replay.json').read_text())
    regen = json.loads((root / 'regeneration/regeneration.json').read_text())
    error = None
    try:
        seal_delivery(spec, capture)
    except ValueError as exc:
        error = str(exc)
    checks = {'native_geometry_ownership_and_mutation': native['passed'], 'facing': json.loads((capture/'facing_report.json').read_text())['passed'],
        'shoulder_rule': abs(after['far_above_near_px']-after['expected_px']) <= PROOF_DEFAULTS['shoulder_tolerance_px'] and after['level_in_3d'],
        'true_180_rotation': bool(true_rotation), 'true_turn_feet_and_depth_both_views': depth_turn,
        'fit_and_part_coverage': fit['passed'], 'exact_native_determinism': exact['passed'],
        'fresh_regeneration': regen['passed'], 'hash_bound_native_delivery': error is None}
    value = {'passed': all(checks.values()), 'spec_hash': digest(spec), 'checks': checks, 'shoulders': shoulders,
        'true_turn_values': turn, 'native_contacts': native, 'delivery_error': error,
        'capture_manifest_sha256': sha(capture/'capture_manifest.json'), 'fit_report_sha256': sha(output/'fit_report.json')}
    write(output / 'mq14_gates.json', value)
    from .review_sheet import sheet
    sheet(spec, capture, output)
    print('MQ14_GATES: ' + ('PASS' if value['passed'] else 'FAIL') + '; ' + str(checks), flush=True)
    return value
