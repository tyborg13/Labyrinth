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
                 'header_px': 28, 'padding_px': 4,
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
    """Native 1024 clay cells share the Lancer's scale; never refit a cell."""
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    references = [('Lancer r3', ROOT / 'gloam_stalker/delivery/reference/lancer_r3'),
                  ('Thrall r2', ROOT / 'arc_thrall/delivery'),
                  ('Burrow Grub / batch B', ROOT / 'burrow_grub/delivery'),
                  ('Ember Tick / batch B', ROOT / 'ember_tick/delivery')]
    native = PROOF_DEFAULTS['native_size']
    row = native + PROOF_DEFAULTS['header_px']
    sheet = Image.new('RGBA', (native * 4, row * 3), PROOF_DEFAULTS['background'])
    draw = ImageDraw.Draw(sheet)
    receipts, results, coverage = {}, [], []
    for i, name in enumerate(FIGURES):
        capture = Path(captures[name])
        result = json.loads((capture / 'fit_report.json').read_text())
        results.append(result)
        with Image.open(capture / 'fit_overlay.png') as overlay:
            # Approved sources/overlay are inspection-only; nearest scaling
            # magnifies their original pixels. Clay cells below remain 1:1.
            image = overlay.convert('RGBA').resize((1020, 510), Image.Resampling.NEAREST)
            sheet.alpha_composite(image, (i * native, PROOF_DEFAULTS['header_px']))
        receipts[str((capture / 'fit_overlay.png').relative_to(ROOT))] = sha(capture / 'fit_overlay.png')
        draw.text((i * native + 4, 4), name + ' / approved fit overlays', fill='white')
        for j, view in enumerate(('front', 'rear')):
            path = capture / (view + '_clay.png')
            with Image.open(path) as original:
                image = original.convert('RGBA')
                if image.size != (native, native):
                    raise ValueError('Expected native 1024 clay: ' + str(path))
                sheet.alpha_composite(image, (i * native, (j + 1) * row + 28))
            draw.text((i * native + 4, (j + 1) * row + 4), name + ' / ' + view, fill='white')
            receipts[str(path.relative_to(ROOT))] = sha(path)
            for part, value in result['views'][view].get('per_part_coverage', {}).items():
                coverage.append([name, view, part, value['visible_pixels'], value['solo_pixels'],
                                 value['pure_owner_pixels'], value['visible_fraction_of_solo'],
                                 value['explicit_occlusion'] or ''])
    # Four reference cells at the same native pixels/metre. Both views of each
    # new figure are already in the first three columns.
    for i, (caption, folder) in enumerate(references[:3]):
        path = folder / 'front_clay.png'
        with Image.open(path) as original:
            image = original.convert('RGBA')
            if image.size != (native, native):
                raise ValueError('Reference changed native scale')
            sheet.alpha_composite(image, (3 * native, i * row + 28))
        draw.text((3 * native + 4, i * row + 4), caption, fill='white')
        receipts[str(path.relative_to(ROOT))] = sha(path)
    # Append a final reference row instead of shrinking any existing cell.
    expanded = Image.new('RGBA', (sheet.width, sheet.height + row), PROOF_DEFAULTS['background'])
    expanded.alpha_composite(sheet)
    draw = ImageDraw.Draw(expanded)
    caption, folder = references[3]
    path = folder / 'front_clay.png'
    with Image.open(path) as original:
        expanded.alpha_composite(original.convert('RGBA'), (3 * native, 3 * row + 28))
    draw.text((3 * native + 4, 3 * row + 4), caption, fill='white')
    receipts[str(path.relative_to(ROOT))] = sha(path)
    expanded.save(output / 'contact_sheet.webp', lossless=True, exact=True, method=6)
    with Image.open(output / 'contact_sheet.webp') as decoded:
        if decoded.convert('RGBA').tobytes() != expanded.tobytes():
            raise ValueError('Lossless contact-sheet encoding changed native RGBA')
    write(output / 'contact_sheet.json', {'native_clay_scale': '1:1, 1024 px / 2.4 m',
          'inputs_sha256': receipts, 'output_sha256': sha(output / 'contact_sheet.webp')})
    table = ['| Figure | Front IoU | Rear IoU | Shoulder observed / expected px | Shoulder error px | Gates |',
             '|---|---:|---:|---:|---:|---|']
    for result in results:
        p = result['pose']
        table.append(f"| {result['id']} | {result['views']['front']['iou']:.9f} | "
                     f"{result['views']['rear']['iou']:.9f} | {p['observed_far_above_near_px']:.3f} / "
                     f"{p['expected_far_above_near_px']:.3f} | {p['shoulder_error_px']:.3f} | "
                     f"{'PASS' if result['passed'] else 'FAIL'} |")
    (output / 'fit_table.md').write_text('\n'.join(table) + '\n')
    with (output / 'part_coverage.csv').open('w') as stream:
        writer = csv.writer(stream)
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
