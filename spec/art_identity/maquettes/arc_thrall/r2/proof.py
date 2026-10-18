"""mq-07 numerical gates and native-cell review sheet; never paints new art.

Run after bridge captures. The old delivery stays intact until the director
has resolved the design TODOs and the new native delivery passes every gate.
"""
import argparse
from copy import deepcopy
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe, PROJECT
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from spec.art_identity.maquettes.fitting import measure
from spec.art_identity.maquettes.raster import camera, project
from spec.art_identity.maquettes.arc_thrall.r2.tube_proof import geometry_dimensions, raster_widths


FIGURE = Path(__file__).resolve().parents[1]
PROOF_DEFAULTS = {'size': 1024, 'header_px': 28, 'joint_radius_px': 6,
                  'background': [24, 24, 24, 255], 'near_marker': 'cyan',
                  'far_marker': 'magenta', 'text_colour': 'white', 'padding_px': 4,
                  'length_tolerance_m': 1e-10, 'coordinate_tolerance_px': 1e-8,
                  'matrix_tolerance': 1e-10, 'marker_width_px': 2,
                  'png_compression': 9, 'elbow_crop_px': 256, 'elbow_crop_scale': 3}


def joints(spec):
    return {view: {name: project(spec, point, view, 1024)[:2].tolist()
                   for name, point in spec['joints'].items()} for view in ('front', 'rear')}


def pose_gates(old, new):
    before, after = joints(old), joints(new)
    near, far = (np.asarray(after['front']['shoulder_' + side]) for side in ('near', 'far'))
    expected = .15 * abs(near[0] - far[0])
    length_errors = {bone['name']: abs(np.linalg.norm(np.subtract(new['joints'][bone['tail']], new['joints'][bone['head']])) -
                    np.linalg.norm(np.subtract(old['joints'][bone['tail']], old['joints'][bone['head']])))
                     for bone in old['armature']['bones']}
    feet = {}
    for view in ('front', 'rear'):
        points = {side: after[view]['foot_tip_' + side] for side in ('near', 'far')}
        lower = max(points, key=lambda side: points[side][1])
        other = 'far' if lower == 'near' else 'near'
        feet[view] = {'lower_anatomical_side': lower, 'lower_foot_px': points[lower],
                      'other_foot_px': points[other], 'passed': bool(points[lower][0] > points[other][0])}
    table = {view: {side: {'before': before[view]['shoulder_' + side],
                         'after': after[view]['shoulder_' + side]} for side in ('near', 'far')}
             for view in ('front', 'rear')}
    front_matrix, front_target, _, front_scale = camera(new, 'front')
    rear_matrix, rear_target, _, rear_scale = camera(new, 'rear')
    checks = {'shoulder_height': bool(abs(near[1] - far[1] - expected) <= 10),
              'shoulder_height_is_perspective_only': new['joints']['shoulder_far'][2] == new['joints']['shoulder_near'][2],
              'far_shoulder_x': bool(abs(far[0] - before['front']['shoulder_far'][0]) < PROOF_DEFAULTS['coordinate_tolerance_px']),
              'limb_lengths': bool(max(length_errors.values()) <= PROOF_DEFAULTS['length_tolerance_m']),
              'same_body_half_turn': bool(np.allclose(rear_matrix, np.diag([-1, -1, 1, 1]) @ front_matrix,
                                                      atol=PROOF_DEFAULTS['matrix_tolerance'], rtol=0) and
                                          np.array_equal(front_target, rear_target) and front_scale == rear_scale),
              'lower_foot_right_in_both_views': all(v['passed'] for v in feet.values())}
    # The root and all joints use one default camera with a 180-degree body
    # turn. Reject per-view transforms that could conceal a different pose.
    checks['same_body_half_turn'] &= 'view_transforms' not in new and not new.get('per_view_cloth_pose')
    return {'passed': all(checks.values()), 'checks': checks, 'shoulder_table_px': table,
            'expected_far_above_near_px': expected, 'limb_length_errors_m': length_errors,
            'feet': feet, 'joints_px': after}


def fit(recipe, spec, capture):
    result = {}
    for view in ('front', 'rear'):
        measured = deepcopy(spec)
        measured['fit'].update(recipe['fit'][view])
        measured['unresolved_design'] = deepcopy(recipe.get('unresolved_design', {}))
        report, _ = measure(measured, Image.open(PROJECT / recipe['sources'][view]).convert('RGBA'),
                            raster=load_render(spec, capture, view))
        result[view] = {'iou': report['iou'], 'minimum': recipe['fit'][view]['gate']['iou_min'],
                        'passed': report['iou'] >= recipe['fit'][view]['gate']['iou_min'],
                        'all_fit_diagnostics': report['checks']}
    return result


def review_sheet(old_capture, new_capture, before, after, output):
    size, header = PROOF_DEFAULTS['size'], PROOF_DEFAULTS['header_px']
    crop_size = PROOF_DEFAULTS['elbow_crop_px'] * PROOF_DEFAULTS['elbow_crop_scale']
    sheet = Image.new('RGBA', (3 * size, 2 * (size + header) + crop_size + header), tuple(PROOF_DEFAULTS['background']))
    for row, view in enumerate(('front', 'rear')):
        for column, (capture, kind, table, caption) in enumerate([
                (old_capture, 'clay', before, 'old clay'), (new_capture, 'clay', after, 'new clay'),
                (new_capture, 'parts', after, 'new part map')]):
            with Image.open(capture / (view + '_' + kind + '.png')) as source:
                if source.size != (size, size):
                    raise ValueError('Review requires native 1024 cells')
                cell = source.convert('RGBA')
            draw = ImageDraw.Draw(cell)
            radius = PROOF_DEFAULTS['joint_radius_px']
            for side, colour in [('near', PROOF_DEFAULTS['near_marker']), ('far', PROOF_DEFAULTS['far_marker'])]:
                x, y = table[view]['shoulder_' + side]
                draw.ellipse((x-radius, y-radius, x+radius, y+radius), outline=colour, width=PROOF_DEFAULTS['marker_width_px'])
                draw.text((x + radius, y), 'shoulder_' + side, fill=colour)
            left, top = column * size, row * (size + header)
            sheet.alpha_composite(cell, (left, top + header))
            ImageDraw.Draw(sheet).text((left + PROOF_DEFAULTS['padding_px'], top + PROOF_DEFAULTS['padding_px']),
                                      view + ' | ' + caption, fill=PROOF_DEFAULTS['text_colour'])
        # Read the raw clay again: no joint labels are baked into the crop.
        with Image.open(new_capture / (view + '_clay.png')) as source:
            x, y = after[view]['elbow_near']
            half = PROOF_DEFAULTS['elbow_crop_px'] // 2
            bounds = (round(x) - half, round(y) - half, round(x) + half, round(y) + half)
            crop = source.convert('RGBA').crop(bounds).resize((crop_size, crop_size), Image.Resampling.NEAREST)
        cell_width = 3 * size // 2
        left = row * cell_width + (cell_width - crop_size) // 2
        top = 2 * (size + header)
        sheet.alpha_composite(crop, (left, top + header))
        ImageDraw.Draw(sheet).text((left, top + PROOF_DEFAULTS['padding_px']),
            view + ' | elbow / open mouth | 3x native', fill=PROOF_DEFAULTS['text_colour'])
    sheet.save(output, optimize=True, compress_level=PROOF_DEFAULTS['png_compression'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    recipe = json.loads((FIGURE / 'r2/measurements.json').read_text())
    old_recipe = json.loads((FIGURE / 'measurements.json').read_text())
    old, new = compile_recipe(old_recipe), compile_recipe(recipe)
    output = FIGURE / 'r2/proof'
    output.mkdir(exist_ok=True)
    report = pose_gates(old, new)
    report['tube_geometry'] = geometry_dimensions(new, recipe)
    report.update(spec_hash=digest(new), before_fit=fit(old_recipe, old, FIGURE / 'delivery'),
                  unresolved_design=recipe['unresolved_design'], native_capture_available=bool(args.capture))
    if args.capture:
        report['after_fit'] = fit(recipe, new, args.capture)
        report['tube_widths'] = {view: raster_widths(new, recipe, load_render(new, args.capture, view), view)
                                for view in ('front', 'rear')}
        entry_path = output / 'tube_geometry.json'
        entry = json.loads(entry_path.read_text()) if entry_path.exists() else {}
        report['native_tube_entry_passed'] = entry.get('spec_hash') == digest(new) and entry.get('passed') is True
        try:
            validate_delivery(new, args.capture)
            report['native_delivery_passed'] = True
        except (ValueError, OSError) as error:
            report['native_delivery_passed'] = False
            report['native_delivery_error'] = str(error)
        review_sheet(FIGURE / 'delivery', args.capture, joints(old), joints(new), output / 'shoulder_tube_sheet.png')
    report['passed'] &= (bool(args.capture) and report.get('native_delivery_passed', False) and
                         report.get('native_tube_entry_passed', False) and report['tube_geometry']['passed'] and
                         all(v['passed'] for v in report.get('tube_widths', {}).values()) and
                         all(v['passed'] for v in report.get('after_fit', {}).values()) and not recipe['unresolved_design'])
    (output / 'gates.json').write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    print('MQ07_POSE: ' + ('PASS' if all(report['checks'].values()) else 'FAIL'))
    print('MQ07_TUBE: ' + ('PASS' if report['tube_geometry']['passed'] and report.get('native_tube_entry_passed', False)
                                and all(v['passed'] for v in report.get('tube_widths', {}).values()) else 'FAIL'))
    print('MQ07_DELIVERY: ' + ('PASS' if report['passed'] else 'INCOMPLETE') + '; native_capture=' + str(bool(args.capture)).lower())
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
