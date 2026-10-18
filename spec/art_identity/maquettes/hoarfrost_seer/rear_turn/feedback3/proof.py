"""Assemble bounded native captures; measure the exact mq-06 owner gates."""
from copy import deepcopy
import csv
import json
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.front_gate import compare
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.fitting import measure, keyed_mask, normalise_points, warp_mask, FIT_DEFAULTS

PROOF_DEFAULTS = {'cell_px': 1024, 'approved_painting_enlargement': 4}


def write(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def assemble(folder):
    spec = compile_recipe(json.loads((folder / 'correction_recipe.json').read_text()))
    output = folder / 'capture'
    output.mkdir(exist_ok=True)
    images, joints, counts, native = [], {}, {}, {}
    for view in ('front', 'rear'):
        source = folder / view
        manifest = read_manifest(source, digest(spec), ('full',))
        for name in manifest['images']:
            shutil.copyfile(source / name, output / name)
            images.append(name)
        joints.update(json.loads((source / 'joints_px.json').read_text()))
        counts.update(json.loads((source / 'solo_coverage.json').read_text()))
        native[view] = json.loads((source / 'capture_checks.json').read_text())
    build = json.loads((folder / 'front/build_report.json').read_text())
    facing = json.loads((folder / 'front/facing_report.json').read_text())
    build['checks'].update(rendered_torso_asymmetry=facing['passed'],
        capture_geometry_unchanged=all(row['geometry_unchanged'] for row in native.values()),
        required_solo_coverage=all(counts[view].get(label, 0) > 0 for view in counts for label in spec['labels']))
    build['passed'] = all(build['checks'].values())
    write(output / 'build_report.json', build)
    write(output / 'joints_px.json', joints)
    write(output / 'solo_coverage.json', counts)
    write(output / 'facing_report.json', facing)
    missing = {view: [label for label in spec['labels'] if counts.get(view, {}).get(label, 0) <= 0] for view in ('front', 'rear')}
    write(output / 'ownership_validation.json', {'passed': not any(missing.values()), 'empty_required_solos': missing})
    write(output / 'capture_checks.json', {'passed': build['passed'] and all(row['passed'] for row in native.values()),
        'spec_hash': digest(spec), 'geometry_unchanged': all(row['geometry_unchanged'] for row in native.values()),
        'geometry_checks': build['checks'], 'facing': facing, 'views': native})
    sides = json.loads((folder / 'front/cloak_side.json').read_text())
    other = json.loads((folder / 'rear/cloak_side.json').read_text())
    if sides['pieces'] != other['pieces']:
        raise ValueError('Body-side labels changed between native views')
    sides['view_owner_hashes'].update(other['view_owner_hashes'])
    write(output / 'cloak_side.json', sides)
    shutil.copyfile(folder / 'rear/capture_frame.json', output / 'capture_frame.json')
    write_manifest(output, digest(spec), 'full', images)
    return spec, output


def fixed_iou(mask, source_mask, definition, source_frame):
    extents = []
    for pixels, frame in ((mask, definition), (source_mask, source_frame)):
        y, x = np.nonzero(pixels)
        extents += [normalise_points([x.min(), y.min()], frame), normalise_points([x.max()+1, y.max()+1], frame)]
    bounds = [np.min(extents, axis=0), np.max(extents, axis=0)]
    a = warp_mask(mask, definition, bounds, FIT_DEFAULTS['normalised_height'])
    b = warp_mask(source_mask, source_frame, bounds, FIT_DEFAULTS['normalised_height'])
    return float((a & b).sum() / (a | b).sum())


def sheet(paths, output, painting_index=None):
    size = PROOF_DEFAULTS['cell_px']
    result = Image.new('RGBA', (len(paths) * size, size))
    for index, path in enumerate(paths):
        with Image.open(path) as image:
            image = image.convert('RGBA')
            if index == painting_index:
                factor = PROOF_DEFAULTS['approved_painting_enlargement']
                image = image.resize((image.width * factor, image.height * factor), Image.Resampling.NEAREST)
            elif image.size != (size, size):
                raise ValueError('Native maquette proof cell size changed')
            result.paste(image, (index * size + (size-image.width)//2, (size-image.height)//2))
    result.save(output, optimize=True)


def main():
    folder = Path(__file__).resolve().parent
    recipe = json.loads((folder / 'correction_recipe.json').read_text())
    spec, capture = assemble(folder)
    baseline = folder / 'baseline_front'
    if not baseline.exists():
        figure = folder.parents[1]
        if (folder / 'baseline_recipe.json').read_bytes() != (figure / 'measurements.json').read_bytes():
            raise ValueError('Restore archived original front inputs before measuring the gate')
        baseline = figure / 'delivery'
    gate = compare(baseline, capture,
                   json.loads((folder.parent / 'feedback2/gate_contract.json').read_text()))
    write(folder / 'front_gate.json', gate)
    reports, rows = {}, []
    for view in ('front', 'rear'):
        measured = deepcopy(spec)
        measured['fit'].update(recipe['fit'][view])
        if view == 'rear':
            measured['fit']['gate']['iou_min'] = recipe['rear_capture']['iou_min']
        raster = load_render(spec, capture, view)
        source = Image.open(PROJECT / recipe['sources'][view]).convert('RGBA')
        report, _ = measure(measured, source, raster=raster)
        coverage = part_coverage(spec, raster, Image.open(capture / f'{view}_parts.png').convert('RGBA'))
        missing = []
        for name, values in coverage.items():
            occlusion = None
            if not values['pure_owner_pixels']:
                occlusion = {'basis': 'depth-tested native map over the unoccluded solo',
                    'occluding_labels': {label: int((raster.masks[name] & (raster.owners == index)).sum())
                        for index, label in enumerate(raster.names) if label != name and
                        (raster.masks[name] & (raster.owners == index)).any()}}
            values['recorded_occlusion'] = occlusion
            if not values['solo_pixels'] or (not values['pure_owner_pixels'] and not occlusion):
                missing.append(name)
            rows.append([view, name, values['pure_owner_pixels'], values['solo_pixels'], json.dumps(occlusion)])
        report['per_part_coverage'] = coverage
        report['required_part_coverage_passed'] = not missing
        report['unit_iou_gate_passed'] = report['iou'] >= measured['fit']['gate']['iou_min']
        reports[view] = report
        write(capture / f'{view}_proportion_report.json', report)
    frame = json.loads((capture / 'capture_frame.json').read_text())['rear']
    original = json.loads((folder.parent / 'feedback2/fit_registration_diagnostic.json').read_text())
    fixed_frame = deepcopy(original['fixed_maquette_frame'])
    fixed_frame['head_top'] += frame['pan_px'][1]
    fixed_frame['sole_bottom'] += frame['pan_px'][1]
    fixed_frame['ground_x'] += frame['pan_px'][0]
    rear_raster = load_render(spec, capture, 'rear')
    old_painting = PROJECT / recipe['sources']['rear']
    fixed = fixed_iou(rear_raster.silhouette, keyed_mask(Image.open(old_painting)), fixed_frame,
                      original['fixed_source_frame'])
    image_margins = {}
    for path in capture.glob('rear_*.png'):
        alpha = np.array(Image.open(path).convert('RGBA'))[..., 3]
        y, x = np.nonzero(alpha)
        if len(x):
            image_margins[path.name] = [int(x.min()), int(y.min()), int(1023-x.max()), int(1023-y.max())]
    result = {'front_gate': gate, 'views': reports, 'rear_iou_before': .7550728331405493,
        'rear_iou_dynamic': reports['rear']['iou'], 'rear_iou_fixed_original': fixed,
        'rear_fixed_frame_with_pan': fixed_frame, 'rear_capture_frame': frame,
        'rear_image_margins_px': image_margins,
        'passed': gate['passed'] and reports['rear']['unit_iou_gate_passed'] and
            all(report['required_part_coverage_passed'] for report in reports.values()) and
            min(min(value) for value in image_margins.values()) >= recipe['rear_capture']['edge_margin_px']}
    write(folder / 'proof_report.json', result)
    with (folder / 'rear_coverage.csv').open('w', newline='') as stream:
        writer = csv.writer(stream);writer.writerow(['view','label','genuine_colour_pixels','solo_pixels','recorded_occlusion']);writer.writerows(rows)
    sheet([capture/'rear_clay.png', capture/'rear_parts.png', old_painting], folder/'rear_sheet.png', 2)
    old_rear = folder / 'old_rear_clay.png'
    if not old_rear.exists():
        old_rear = folder.parents[1] / 'delivery/rear_clay.png'
    sheet([capture/'front_clay.png',old_rear,capture/'rear_clay.png',old_painting,capture/'rear_parts.png'],folder/'before_after_sheet.png',3)
    print('MQ06_FRONT_GATE: ' + str(gate['passed']) + '; alpha=' + str(gate['whole_figure_alpha_changed_pixels']))
    print('MQ06_REAR_FIT: dynamic=' + str(reports['rear']['iou']) + '; fixed_original=' + str(fixed))
    print('MQ06_PROOF: ' + ('PASS' if result['passed'] else 'FAIL'))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
