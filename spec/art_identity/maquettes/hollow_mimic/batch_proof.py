"""mq-09 acceptance evidence from native captures; never authors artwork."""
import argparse
import csv
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe, PROJECT
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.fit_delivery import overlay_parts, registered_parts
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.blender.solid_fit import silhouette_fit
from spec.art_identity.maquettes.blender.floor_contact import spec_contacts
from spec.art_identity.maquettes.raster import project


FIGURES = ('hollow_mimic', 'briar_weaver', 'slag_mortar')
ROOT = PROJECT / 'spec/art_identity/maquettes'
PROOF_DEFAULTS = {'shoulder_tolerance_px': 10, 'joint_tolerance_px': .02,
                 'height_tolerance_m': 1e-8, 'native_size': 1024,
                 'header_px': 28, 'padding_px': 4, 'sheet_columns': 4, 'sheet_rows': 5,
                 'painting_scale': 4, 'reference_row': 3, 'overlay_row': 4,
                 'background': (24, 24, 24, 255), 'caption': 'white',
                 'overlay_opacity': .4}


def pose_gates(spec, recorded=None):
    joints = {v: {k: project(spec, p, v, 1024)[:2].tolist()
                  for k, p in spec['joints'].items()} for v in ('front', 'rear')}
    near, far = (joints['front']['shoulder_' + side] for side in ('near', 'far'))
    expected = .15 * abs(near[0] - far[0])
    observed = near[1] - far[1]
    shoulder_height = abs(spec['joints']['shoulder_near'][2] - spec['joints']['shoulder_far'][2])
    checks = {'shoulder_rule': abs(observed - expected) <= PROOF_DEFAULTS['shoulder_tolerance_px'],
              'shoulders_level_3d': shoulder_height <= PROOF_DEFAULTS['height_tolerance_m'],
              'feet_planted': spec_contacts(spec)['passed']}
    feet = {}
    for view in ('front', 'rear'):
        points = {side: joints[view]['foot_tip_' + side] for side in ('near', 'far')}
        lower, higher = sorted(points, key=lambda side: points[side][1], reverse=True)
        feet[view] = {'points': points, 'lower_side': lower,
                      'lower_foot_right': points[lower][0] > points[higher][0]}
        checks[view + '_lower_foot_right'] = feet[view]['lower_foot_right']
    if recorded is not None:
        checks['native_joint_inventory'] = all(set(recorded[v]) == set(joints[v]) for v in joints)
        errors = [float(np.linalg.norm(np.subtract(p, recorded[v][k])))
                  for v, values in joints.items() for k, p in values.items()]
        checks['native_joint_projection'] = max(errors) <= PROOF_DEFAULTS['joint_tolerance_px']
    return {'passed': all(checks.values()), 'checks': checks, 'joints_px': joints,
            'expected_far_above_near_px': expected, 'observed_far_above_near_px': observed,
            'shoulder_error_px': abs(observed - expected), 'shoulder_height_difference_m': shoulder_height,
            'feet': feet, 'floor': spec_contacts(spec)}


def inspect(folder, capture, full=True):
    folder, capture = Path(folder).resolve(), Path(capture).resolve()
    recipe = json.loads((folder / 'measurements.json').read_text())
    spec = compile_recipe(recipe)
    recorded = json.loads((capture / 'joints_px.json').read_text())
    pose = pose_gates(spec, recorded)
    views, overlays, mortar_head = {}, [], {}
    for view, minimum in (('front', .70), ('rear', .65)):
        source_path = PROJECT / recipe['sources'][view]
        if sha(source_path) != recipe['source_sha256'][view]:
            raise ValueError('Protected source changed: ' + str(source_path))
        with Image.open(source_path) as original:
            source = original.convert('RGBA')
        raster = load_render(spec, capture, view)
        report = silhouette_fit(source, raster, minimum)
        with Image.open(capture / (view + '_parts.png')) as original:
            parts = original.convert('RGBA')
        if spec['id'] == 'slag_mortar':
            from spec.art_identity.maquettes.slag_mortar.occlusion_pixels import overlap
            mortar_head[view] = overlap(spec, parts, raster.masks['head'])
        if full:
            coverage = part_coverage(spec, raster, parts)
            for name, value in coverage.items():
                value['explicit_occlusion'] = recipe['occlusions'][view].get(name)
            missing = [name for name, value in coverage.items() if not value['solo_pixels'] or
                       value['clipped_at_canvas'] or
                       (not value['pure_owner_pixels'] and not value['explicit_occlusion'])]
            report.update(per_part_coverage=coverage, missing_unoccluded_parts=missing)
            report['passed'] &= not missing
        overlays.append(overlay_parts(source, registered_parts(parts, report, source.size),
                                      PROOF_DEFAULTS['overlay_opacity']))
        views[view] = report
    result = {'id': spec['id'], 'spec_hash': digest(spec), 'pose': pose,
              'views': views, 'passed': pose['passed'] and all(v['passed'] for v in views.values()),
              'inputs': {'recipe_sha256': sha(folder / 'measurements.json'),
                         'capture_manifest_sha256': sha(capture / 'capture_manifest.json'),
                         'source_sha256': recipe['source_sha256']}}
    if full:
        # Independent pixel/depth-order regression, shared with mq-06. Body
        # labels never swap and the rear comes from the same frozen geometry.
        from tests.test_maquette_rear_turn import observations
        turn = observations(capture)
        checks = {v + '_lower_foot_right': turn[v]['lower_foot_right'] for v in turn}
        checks['front_near_over_torso'] = (turn['front']['body_side_pixels_over_torso']['near'] >
                                           turn['front']['body_side_pixels_over_torso']['far'])
        checks['rear_far_over_torso'] = (turn['rear']['body_side_pixels_over_torso']['far'] >
                                        turn['rear']['body_side_pixels_over_torso']['near'])
        result['true_turn'] = {'observations': turn, 'checks': checks, 'passed': all(checks.values())}
        result['passed'] &= result['true_turn']['passed']
    if mortar_head:
        checks = {'front_head_clear_of_mortar': mortar_head['front']['genuine_mortar_over_head_pixels'] == 0,
                  'rear_head_partly_covered_by_mortar': mortar_head['rear']['genuine_mortar_over_head_pixels'] > 0}
        result['mortar_head_occlusion'] = {'views': mortar_head, 'checks': checks, 'passed': all(checks.values())}
        result['passed'] &= result['mortar_head_occlusion']['passed']
    overlay = Image.new('RGBA', (sum(p.width for p in overlays), max(p.height for p in overlays)))
    for i, image in enumerate(overlays):
        overlay.paste(image, (i * image.width, 0))
    write(capture / 'fit_report.json', result)
    overlay.save(capture / 'fit_overlay.png', optimize=True)
    print('MQ09_FIT: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + spec['id'] + '; ' +
          '; '.join(v + '_iou=' + format(r['iou'], '.9f') for v, r in views.items()), flush=True)
    return result


def review_sheet(captures, output):
    """Approved painting | native clay, both views, at the shared board scale."""
    import os
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    references = [('Lancer r3', ROOT / 'gloam_stalker/delivery/reference/lancer_r3'),
                  ('Thrall r2', ROOT / 'arc_thrall/delivery'),
                  ('Burrow Grub / batch B', ROOT / 'burrow_grub/delivery'),
                  ('Ember Tick / batch B', ROOT / 'ember_tick/delivery')]
    native = PROOF_DEFAULTS['native_size']
    height = native + PROOF_DEFAULTS['header_px']
    sheet = Image.new('RGBA', (native * PROOF_DEFAULTS['sheet_columns'], height * PROOF_DEFAULTS['sheet_rows']), PROOF_DEFAULTS['background'])
    draw = ImageDraw.Draw(sheet)
    receipts, results, coverage, cells = {}, [], [], []
    before = json.loads((output / 'form_revision_before.json').read_text())

    def cell(path, column, row, caption, kind):
        with Image.open(path) as original:
            picture = original.convert('RGBA')
        if kind == 'painting':
            size = tuple(d * PROOF_DEFAULTS['painting_scale'] for d in picture.size)
            if max(size) > native:
                raise ValueError('Approved painting exceeds the native board cell')
            # Processed sources are 255 px crops of the nominal 256 px
            # board. Preserve exact 4x pixels; never stretch them to 1024.
            picture = picture.resize(size, Image.Resampling.NEAREST)
        elif picture.size != (native, native):
            raise ValueError('Expected native 1024 clay')
        x, y = column * native, row * height
        sheet.alpha_composite(picture, (x, y + PROOF_DEFAULTS['header_px']))
        draw.text((x + 4, y + 4), caption, fill=PROOF_DEFAULTS['caption'])
        name = os.path.relpath(path, ROOT)
        receipts[name] = sha(path)
        cells.append({'kind': kind, 'path': name, 'column': column, 'row': row,
                      'source_scale': PROOF_DEFAULTS['painting_scale'] if kind == 'painting' else 1})

    for row, name in enumerate(FIGURES):
        capture = Path(captures[name])
        recipe = json.loads((ROOT / name / 'measurements.json').read_text())
        result = json.loads((capture / 'fit_report.json').read_text())
        results.append(result)
        for j, view in enumerate(('front', 'rear')):
            cell(PROJECT / recipe['sources'][view], j * 2, row,
                 name + ' / ' + view + ' / approved painting', 'painting')
            cell(capture / (view + '_clay.png'), j * 2 + 1, row,
                 name + ' / ' + view + ' / revised clay', 'clay')
            for part, value in result['views'][view].get('per_part_coverage', {}).items():
                coverage.append([name, view, part, value['visible_pixels'], value['solo_pixels'],
                                 value['pure_owner_pixels'], value['visible_fraction_of_solo'],
                                 value['explicit_occlusion'] or ''])
        overlay_path = capture / 'fit_overlay.png'
        with Image.open(overlay_path) as original:
            overlay = original.convert('RGBA').resize((native, native // 2), Image.Resampling.NEAREST)
        sheet.alpha_composite(overlay, (row * native, PROOF_DEFAULTS['overlay_row'] * height + PROOF_DEFAULTS['header_px']))
        draw.text((row * native + 4, PROOF_DEFAULTS['overlay_row'] * height + PROOF_DEFAULTS['padding_px']), name + ' / fit overlays', fill='white')
        receipts[os.path.relpath(overlay_path, ROOT)] = sha(overlay_path)
    for column, (caption, folder) in enumerate(references):
        cell(folder / 'front_clay.png', column, PROOF_DEFAULTS['reference_row'], caption + ' / same native scale', 'reference_clay')
    sheet.save(output / 'contact_sheet.webp', lossless=True, exact=True, method=6)
    with Image.open(output / 'contact_sheet.webp') as decoded:
        if decoded.convert('RGBA').tobytes() != sheet.tobytes():
            raise ValueError('Lossless contact-sheet encoding changed native RGBA')
    write(output / 'contact_sheet.json', {'native_clay_scale': '1:1, 1024 px / 2.4 m',
          'painting_scale': '4:1 nearest; same source board projection', 'cells': cells,
          'inputs_sha256': receipts, 'output_sha256': sha(output / 'contact_sheet.webp')})
    table = ['| Figure | Front IoU before → after | Rear IoU before → after | Shoulder observed / expected px | Shoulder error px | Gates |',
             '|---|---:|---:|---:|---:|---|']
    for result in results:
        name = result['id']; p = result['pose']; old = before[name]['fit_report']['views']
        table.append(f"| {name} | {old['front']['iou']:.9f} → {result['views']['front']['iou']:.9f} | "
                     f"{old['rear']['iou']:.9f} → {result['views']['rear']['iou']:.9f} | "
                     f"{p['observed_far_above_near_px']:.3f} / {p['expected_far_above_near_px']:.3f} | "
                     f"{p['shoulder_error_px']:.3f} | {'PASS' if result['passed'] else 'FAIL'} |")
    (output / 'fit_table.md').write_text('\n'.join(table) + '\n')
    with (output / 'part_coverage.csv').open('w') as stream:
        writer = csv.writer(stream, lineterminator='\n')
        writer.writerow(['figure', 'view', 'part', 'visible_pixels', 'solo_pixels',
                         'pure_owner_pixels', 'visible_fraction_of_solo', 'explicit_occlusion'])
        writer.writerows(coverage)
    write(output / 'gates.json', results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture-subdir', default='delivery')
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--sheet', action='store_true')
    args = parser.parse_args()
    captures = {name: ROOT / name / args.capture_subdir for name in FIGURES}
    results = [inspect(ROOT / name, captures[name], full=not args.preview) for name in FIGURES]
    if args.sheet:
        review_sheet(captures, ROOT / 'hollow_mimic/delivery/review')
    return 0 if all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
