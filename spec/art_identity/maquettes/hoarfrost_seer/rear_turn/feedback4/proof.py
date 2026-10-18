"""Rear-only owner gates and the native 1024 four-cell inspection sheet."""
from copy import deepcopy
import csv
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import sha
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.fitting import measure, keyed_mask
from spec.art_identity.maquettes.hoarfrost_seer.rear_turn.feedback3.proof import fixed_iou, sheet


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    folder = Path(__file__).resolve().parent
    figure, capture = folder.parents[1], folder / 'rear'
    recipe = json.loads((folder / 'rear_recipe.json').read_text())
    spec = compile_recipe(recipe)
    raster = load_render(spec, capture, 'rear')
    measured = deepcopy(spec)
    measured['fit'].update(recipe['fit']['rear'])
    measured['fit']['gate']['iou_min'] = recipe['rear_capture']['iou_min']
    painting = PROJECT / recipe['sources']['rear']
    fit, comparison = measure(measured, Image.open(painting).convert('RGBA'), raster=raster)
    comparison.save(folder / 'rear_registration_comparison.png')
    coverage = part_coverage(spec, raster, Image.open(capture / 'rear_parts.png').convert('RGBA'))
    for name, row in coverage.items():
        row['recorded_occlusion'] = None
        if not row['pure_owner_pixels']:
            row['recorded_occlusion'] = {'basis': 'native depth-tested map over complete solo',
                'occluding_labels': {label: int((raster.masks[name] & (raster.owners == index)).sum())
                    for index, label in enumerate(raster.names) if label != name and
                    (raster.masks[name] & (raster.owners == index)).any()}}
    fit['per_part_coverage'] = coverage
    frame = json.loads((capture / 'capture_frame.json').read_text())['rear']
    original = json.loads((folder.parent / 'feedback2/fit_registration_diagnostic.json').read_text())
    fixed_frame = deepcopy(original['fixed_maquette_frame'])
    for key in ('head_top', 'sole_bottom'):
        fixed_frame[key] += frame['pan_px'][1]
    fixed_frame['ground_x'] += frame['pan_px'][0]
    fixed = fixed_iou(raster.silhouette, keyed_mask(Image.open(painting)), fixed_frame, original['fixed_source_frame'])
    frozen = json.loads((folder / 'front_freeze.json').read_text())
    front_ok = (frozen['files'] == {p.name: sha(p) for p in (figure / 'delivery').glob('front_*')} and
        frozen['joints'] == json.loads((figure / 'delivery/joints_px.json').read_text())['front'])
    margins = {}
    for path in capture.glob('rear_*.png'):
        y, x = np.nonzero(np.array(Image.open(path).convert('RGBA'))[..., 3])
        if len(x):
            margins[path.name] = [int(x.min()), int(y.min()), int(1023-x.max()), int(1023-y.max())]
    build = json.loads((capture / 'build_report.json').read_text())
    checks = {'front_bytes_and_joints_frozen': front_ok, 'native_build': build['passed'],
        'rear_iou': fit['iou'] >= recipe['rear_capture']['iou_min'],
        'rear_coverage': all(row['solo_pixels'] and (row['pure_owner_pixels'] or row['recorded_occlusion']) for row in coverage.values()),
        'pan_only_frame': frame['passed'] and min(min(row) for row in margins.values()) >= recipe['rear_capture']['edge_margin_px']}
    result = {'passed': all(checks.values()), 'checks': checks, 'rear_iou_before': .7550728331405493,
        'rear_iou_dynamic': fit['iou'], 'rear_iou_fixed_original': fixed, 'rear_iou_min': .60,
        'rear_fixed_frame_with_pan': fixed_frame, 'rear_capture_frame': frame,
        'rear_image_margins_px': margins, 'per_part_coverage': coverage,
        'view_roots_px': {'front_frozen': frozen['joints']['root'],
            'rear_candidate': json.loads((capture / 'joints_px.json').read_text())['rear']['root']}}
    write(folder / 'proof_report.json', result)
    write(folder / 'rear_fit_report.json', fit)
    with (folder / 'rear_coverage.csv').open('w') as stream:
        writer = csv.writer(stream)
        writer.writerow(['label', 'genuine_colour_pixels', 'solo_pixels', 'recorded_occlusion'])
        for name, row in coverage.items():
            writer.writerow([name, row['pure_owner_pixels'], row['solo_pixels'], json.dumps(row['recorded_occlusion'])])
    old_rear = figure / 'delivery/rear_clay.png'
    sheet([old_rear, capture / 'rear_clay.png', capture / 'rear_parts.png', painting], folder / 'rear_sheet.png', 3)
    floor = build['geometry_details']['floor_contact']
    extent = json.loads((folder / 'rear_extent.json').read_text())
    far_hem = extent['hem_shell_heights_m']['skirt_far']
    heights = {'floor_plane_m': floor['floor_m'], 'rows': {
        'far_ankle': {'before_m': floor['pose']['joints_before']['ankle_far'][2], 'after_m': floor['points']['ankle_far']['height_m']},
        'far_hem_min': {'before_m': .116210013628, 'after_m': far_hem['min']},
        'far_hem_max': {'before_m': .313963472843, 'after_m': far_hem['max']},
        'staff_butt': {'before_m': -.0022594720980433068, 'after_m': floor['points']['staff_shaft.prop_foot']['height_m']}},
        'hem_after_scope': 'far-side rendered hem shell vertices; before is the original far-hem midsurface',
        'rear_extent': extent}
    write(folder / 'height_table.json', heights)
    print('MQ06_FRONT_FREEZE: ' + ('PASS' if front_ok else 'FAIL') + '; files=' + str(len(frozen['files'])) + '; joints unchanged=' + str(front_ok))
    print('MQ06_REAR_FIT: dynamic=' + str(fit['iou']) + '; fixed_original=' + str(fixed) + '; before=0.7550728331405493')
    print('MQ06_PROOF: ' + ('PASS' if result['passed'] else 'FAIL'))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
