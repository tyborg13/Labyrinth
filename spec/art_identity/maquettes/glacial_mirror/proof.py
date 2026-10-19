"""Native 1024 mq-08 comparison sheet and reproducible shoulder/fit gates."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from spec.art_identity.maquettes.blender.solid_fit import compute_fit
from spec.art_identity.maquettes.blender.solid_review import save_review_sheet
from spec.art_identity.maquettes.glacial_mirror.shoulder_revision import revise, SHOULDER_CONTRACT
from spec.art_identity.maquettes.glacial_mirror.guards import geometry_checks

PROOF_DEFAULTS = {'cell_px': 1024, 'caption_px': 32, 'background': (24, 24, 24, 255),
                  'caption_colour': 'white', 'near_marker': '#ffdf50', 'far_marker': '#50e5ff',
                  'marker_radius_px': 6, 'marker_line_px': 2, 'caption_padding_px': 8,
                  'numerical_tolerance_m': 1e-9, 'caption_font': 'monospace', 'caption_font_px': 12}
FIGURE = Path(__file__).resolve().parent


def mass_top(folder, view, part):
    with Image.open(folder / f'{view}_solo_{part}.png') as image:
        mask = np.asarray(image.convert('RGBA'))[:, :, 3] >= 128
    y, x = np.nonzero(mask)
    if not len(y):
        raise ValueError('Missing mass: ' + part)
    top = int(y.min())
    return [float(np.median(x[y == top])), top]


def evaluate(before, after):
    before_path = FIGURE / 'proof/measurements_before.json'
    if not before_path.exists():
        before_path = FIGURE / 'delivery/review/mq08_before_recipe.json'
    before_recipe = json.loads(before_path.read_text())
    recipe = json.loads((FIGURE / 'measurements.json').read_text())
    old, spec = compile_recipe(before_recipe), compile_recipe(recipe)
    baseline_path = FIGURE / 'delivery/review/mq08_before_capture.json'
    if (before / 'joints_px.json').is_file():
        baseline = {'joints': json.loads((before / 'joints_px.json').read_text()),
                    'fit_report': json.loads((before / 'fit_report.json').read_text()),
                    'mesh_hashes': json.loads((before / 'build_report.json').read_text())['mesh_hashes'],
                    'mass_tops_px': {v: {p: mass_top(before, v, p) for p in ('upper_near', 'upper_far', 'head')} for v in ('front', 'rear')},
                    'source_sha256': {p.name: sha(p) for p in before.glob('*') if p.name in ('joints_px.json', 'fit_report.json', 'build_report.json') or
                                      p.name in {f'{v}_solo_{part}.png' for v in ('front', 'rear') for part in ('upper_near', 'upper_far', 'head')}},
                    'clay_rgba_sha256': {}}
        for view in ('front', 'rear'):
            path = before / f'{view}_clay.png'
            baseline['source_sha256'][path.name] = sha(path)
            with Image.open(path) as image:
                baseline['clay_rgba_sha256'][view] = hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest()
        write(baseline_path, baseline)
    else:
        baseline = json.loads(baseline_path.read_text())
    joints = {'before': baseline['joints'], 'after': json.loads((after / 'joints_px.json').read_text())}
    near, far = (joints['after']['front']['shoulder_' + side] for side in ('near', 'far'))
    expected = near[1] - SHOULDER_CONTRACT['slope'] * abs(near[0] - far[0])
    tops = {'before': baseline['mass_tops_px'], 'after': {
        v: {p: mass_top(after, v, p) for p in ('upper_near', 'upper_far', 'head')} for v in ('front', 'rear')}}
    front = tops['after']['front']
    expected_top = front['upper_near'][1] - SHOULDER_CONTRACT['slope'] * abs(near[0] - far[0])
    changes = set(recipe['shoulder_revision_contract']['changed_joints'])
    protected_joints = all(value == spec['joints'][name] for name, value in old['joints'].items() if name not in changes)
    allowed = {'upper_far', 'fore_far', 'hand_far', 'shoulder_far_mass', 'elbow_far_bedding'}
    protected_surfaces = all(a == b for a, b in zip(old['pieces'], spec['pieces']) if a['id'] not in allowed)
    lengths = {b['name']: [float(np.linalg.norm(np.subtract(s['joints'][b['tail']], s['joints'][b['head']])))
                          for s in (old, spec)] for b in spec['armature']['bones']}
    build = json.loads((after / 'build_report.json').read_text())
    fit, _ = compute_fit(FIGURE, after)
    prior_fit = baseline['fit_report']
    checks = {
        'reproduced_recipe': revise(before_recipe) == recipe,
        'far_shoulder_x': abs(far[0] - joints['before']['front']['shoulder_far'][0]) <= SHOULDER_CONTRACT['joint_tolerance_px'],
        'level_3d_shoulders': abs(spec['joints']['shoulder_near'][2] - spec['joints']['shoulder_far'][2]) <= PROOF_DEFAULTS['numerical_tolerance_m'],
        'pauldron_below_head': front['upper_far'][1] >= front['head'][1],
        'every_limb_length': all(abs(a - b) <= PROOF_DEFAULTS['numerical_tolerance_m'] for a, b in lengths.values()),
        'protected_joints': protected_joints, 'protected_surfaces': protected_surfaces,
        'protected_native_meshes': all(value == build['mesh_hashes'].get(name) for name, value in baseline['mesh_hashes'].items()
                                       if name not in {part + '_render' for part in allowed}),
        'locked_15_labels': len(spec['labels']) == 15 and recipe['labels'] == before_recipe['labels'],
        'native_geometry': build['passed'], 'fit_and_coverage': fit['passed']}
    checks.update(geometry_checks(spec, joints['after']['front'], front))
    covered = {}
    for view in ('front', 'rear'):
        with Image.open(after / f'{view}_solo_upper_far.png') as image:
            alpha = np.asarray(image.convert('RGBA'))[:, :, 3]
        x, y = np.rint(joints['after'][view]['shoulder_far']).astype(int)
        covered[view] = bool(0 <= x < alpha.shape[1] and 0 <= y < alpha.shape[0] and alpha[y, x] >= 128)
    checks['shoulder_joint_covered_both_views'] = all(covered.values())
    validate_delivery(spec, after)
    checks['sealed_delivery_cold_and_exact_replay'] = True
    return {'passed': all(checks.values()), 'checks': {k: bool(v) for k, v in checks.items()},
            'spec_hash': digest(spec), 'recipe_sha256': sha(FIGURE / 'measurements.json'),
            'joints': joints, 'mass_tops_px': tops, 'front_shoulder_target_y': expected,
            'front_pauldron_target_y': expected_top, 'limb_lengths_m': lengths,
            'shoulder_coverage': covered,
            'baseline_clay_rgba_sha256': baseline['clay_rgba_sha256'],
            'fit_iou': {v: {'before': prior_fit['views'][v]['iou'], 'after': fit['views'][v]['iou'],
                           'minimum': fit['views'][v]['iou_min']} for v in ('front', 'rear')}}


def raster_sheet(before, after, result, output):
    size, caption = PROOF_DEFAULTS['cell_px'], PROOF_DEFAULTS['caption_px']
    sheet = Image.new('RGBA', (size * 3, (size + caption) * 2), PROOF_DEFAULTS['background'])
    drawing = ImageDraw.Draw(sheet)
    for row, view in enumerate(('front', 'rear')):
        for column, (label, folder, kind) in enumerate((('before', before, 'clay'), ('after', after, 'clay'), ('after', after, 'parts'))):
            path = folder / f'{view}_{kind}.png'
            if label == 'before' and not path.is_file():
                path = FIGURE / f'delivery/review/mq08_old_{view}_clay.webp'
            with Image.open(path) as image:
                if image.size != (size, size):
                    raise ValueError('Proof cells must be native 1024 without resampling')
                cell = image.convert('RGBA')
            x, y = column * size, row * (size + caption) + caption
            sheet.alpha_composite(cell, (x, y))
            drawing.text((x + PROOF_DEFAULTS['caption_padding_px'], y - caption + PROOF_DEFAULTS['caption_padding_px']),
                         f'{view}: {label} {kind}; circles = shoulder joints; crosses = mass tops', fill=PROOF_DEFAULTS['caption_colour'])
            radius = PROOF_DEFAULTS['marker_radius_px']
            for side in ('near', 'far'):
                colour = PROOF_DEFAULTS[side + '_marker']
                px, py = result['joints'][label][view]['shoulder_' + side]
                drawing.ellipse((x + px - radius, y + py - radius, x + px + radius, y + py + radius), outline=colour, width=PROOF_DEFAULTS['marker_line_px'])
                px, py = result['mass_tops_px'][label][view]['upper_' + side]
                drawing.line((x + px - radius, y + py, x + px + radius, y + py), fill=colour, width=PROOF_DEFAULTS['marker_line_px'])
                drawing.line((x + px, y + py - radius, x + px, y + py + radius), fill=colour, width=PROOF_DEFAULTS['marker_line_px'])
    return save_review_sheet(sheet, output)


def linked_sheet(before, after, result, output):
    """A self-contained local sheet reuses native captures instead of duplicating them.

    The old clays are lossless WebP copies, independently RGBA checked. Current
    clays/maps remain the exact native delivery PNGs. CSS fixes every cell and
    SVG coordinate system at 1024 px; no image is resized or repainted.
    """
    import html
    import os
    size, caption = PROOF_DEFAULTS['cell_px'], PROOF_DEFAULTS['caption_px']
    old_clays, cells, markup = {}, [], []
    for view in ('front', 'rear'):
        target = output.parent / f'mq08_old_{view}_clay.webp'
        source = before / f'{view}_clay.png'
        if source.is_file():
            with Image.open(source) as image:
                old_clays[view] = save_review_sheet(image.convert('RGBA'), target)
        else:
            with Image.open(target) as image:
                rgba = image.convert('RGBA')
                old_clays[view] = {'format': 'lossless WebP', 'rgba_identical': True,
                    'size': list(image.size), 'rgba_sha256': hashlib.sha256(rgba.tobytes()).hexdigest(),
                    'file_sha256': sha(target)}
        if old_clays[view]['rgba_sha256'] != result['baseline_clay_rgba_sha256'][view]:
            raise ValueError('Historical clay pixels differ from the frozen mq-05 baseline')
        for label, path, kind in (('before', target, 'clay'), ('after', after / f'{view}_clay.png', 'clay'),
                                  ('after', after / f'{view}_parts.png', 'parts')):
            relative = os.path.relpath(path, output.parent)
            marks = []
            for side in ('near', 'far'):
                colour, radius = PROOF_DEFAULTS[side + '_marker'], PROOF_DEFAULTS['marker_radius_px']
                x, y = result['joints'][label][view]['shoulder_' + side]
                marks.append(f'<circle cx="{x}" cy="{y}" r="{radius}" stroke="{colour}"/>')
                x, y = result['mass_tops_px'][label][view]['upper_' + side]
                marks.append(f'<path d="M{x-radius},{y}h{radius*2}M{x},{y-radius}v{radius*2}" stroke="{colour}"/>')
            title = f'{view}: {label} {kind}; circles = shoulder joints; crosses = mass tops'
            markup.append(f'<figure><figcaption>{html.escape(title)}</figcaption><div class="native">'
                f'<img src="{html.escape(relative)}" width="{size}" height="{size}" alt="{html.escape(title)}">'
                f'<svg viewBox="0 0 {size} {size}" width="{size}" height="{size}" fill="none" '
                f'stroke-width="{PROOF_DEFAULTS["marker_line_px"]}">{"".join(marks)}</svg></div></figure>')
            cells.append({'path': relative, 'sha256': sha(path), 'view': view, 'state': label, 'kind': kind})
    background = ','.join(str(v) for v in PROOF_DEFAULTS['background'][:3])
    document = f'''<!doctype html>
<html lang="en"><meta charset="utf-8"><title>mq-08 native shoulder proof</title>
<style>
body {{margin:0;background:rgb({background});color:{PROOF_DEFAULTS['caption_colour']}}}
main {{display:grid;grid-template-columns:repeat(3,{size}px);width:{size*3}px}}
figure {{margin:0;width:{size}px}}
figcaption {{box-sizing:border-box;height:{caption}px;padding:{PROOF_DEFAULTS['caption_padding_px']}px;
font:{PROOF_DEFAULTS['caption_font_px']}px {PROOF_DEFAULTS['caption_font']};white-space:nowrap}}
.native {{position:relative;width:{size}px;height:{size}px}}
img,svg {{position:absolute;left:0;top:0;width:{size}px;height:{size}px;display:block}}
svg {{pointer-events:none}}
</style><main>{''.join(markup)}</main></html>'''
    output.write_text(document + '\n')
    return {'format': 'local HTML with native PNG and lossless WebP cells', 'native_cell_size': [size, size],
            'size': [size * 3, (size + caption) * 2], 'resampling': 'none',
            'file_sha256': sha(output), 'old_clays': old_clays, 'cells': cells}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, default=FIGURE / 'proof/before')
    parser.add_argument('--after', type=Path, default=FIGURE / 'delivery')
    parser.add_argument('--export-webp', action='store_true', help='Optional duplicate raster sheet; curation retains the linked native sheet')
    args = parser.parse_args()
    output = FIGURE / 'delivery/review'
    output.mkdir(exist_ok=True)
    result = evaluate(args.before, args.after)
    result['sheet'] = linked_sheet(args.before, args.after, result, output / 'mq08_shoulders.html')
    if args.export_webp:
        raster_sheet(args.before, args.after, result, output / 'mq08_shoulders.webp')
    write(output / 'mq08_gates.json', result)
    shutil_source = FIGURE / 'proof/measurements_before.json'
    if shutil_source.exists():
        (output / 'mq08_before_recipe.json').write_bytes(shutil_source.read_bytes())
    rows = ['| View | Joint | Before (px) | After (px) |', '|---|---|---|---|']
    for view in ('front', 'rear'):
        for name in ('shoulder_near', 'shoulder_far', 'elbow_far', 'hand_far'):
            values = [result['joints'][label][view][name] for label in ('before', 'after')]
            rows.append(f'| {view} | {name} | {values[0]} | {values[1]} |')
    for view, values in result['fit_iou'].items():
        rows.append(f"\n{view} IoU: {values['before']:.9f} → {values['after']:.9f}; minimum {values['minimum']:.2f}.")
    (output / 'mq08_joint_table.md').write_text('\n'.join(rows) + '\n')
    print('MQ08_SHOULDER_GATES: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + json.dumps(result['checks']))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
