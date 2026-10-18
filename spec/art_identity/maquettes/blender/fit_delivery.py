"""Verify bounded capture inventories and report both approved-art fit gates.

The overlay is the approved painting plus registered part labels at exactly
40 percent. It is inspection evidence, never replacement artwork.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from shutil import copy2
import sys

import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.fitting import measure


DELIVERY_DEFAULTS = {'overlay_opacity': .4, 'contact_scale': 2, 'caption_height': 20,
                     'contact_columns': 2, 'caption_padding': 4,
                     'contact_background': [24, 24, 24, 255], 'caption_colour': 'white',
                     'caption_font': 'Pillow default'}


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def overlay_parts(source, parts, opacity):
    """Preserve the painting outside the registered part-map silhouette."""
    pixels = np.asarray(parts).copy()
    pixels[..., 3] = np.rint(pixels[..., 3] * opacity).astype(np.uint8)
    return Image.alpha_composite(source, Image.fromarray(pixels))


def determinism_matches(spec, proof):
    checks = proof.get('checks', {})
    return (proof.get('spec_hash') == digest(spec) and
            checks.get('fresh_and_replay_raw_hashes', False) and checks.get('joint_endpoints', False))


def assemble(folder):
    folder = Path(folder).resolve()
    spec = json.loads((folder / 'spec_native.json').read_text())
    capture = folder / 'proof' / 'capture'
    capture.mkdir(parents=True, exist_ok=True)
    names, joints, counts, signatures = [], {}, {}, {}
    for view in ('front', 'rear'):
        source = folder / 'proof' / view
        manifest = read_manifest(source, digest(spec), ('full',))
        view_joints = json.loads((source / 'joints_px.json').read_text())
        if set(view_joints) != {view} or set(view_joints[view]) != set(spec['joints']):
            raise ValueError('Single-view capture has incorrect joint inventory')
        for name in manifest['images']:
            copy2(source / name, capture / name)
            names.append(name)
        joints.update(view_joints)
        counts.update(json.loads((source / 'solo_coverage.json').read_text()))
        signatures[view] = json.loads((source / 'capture_checks.json').read_text())
        if signatures[view].get('spec_hash') != digest(spec):
            raise ValueError('Capture checks belong to a different spec: ' + view)
        copy2(source / 'capture_manifest.json', capture / (view + '_capture_manifest.json'))
    write(capture / 'joints_px.json', joints)
    write(capture / 'solo_coverage.json', counts)
    write(capture / 'capture_checks.json', signatures)
    copy2(folder / 'proof' / 'build_report.json', capture / 'build_report.json')
    write_manifest(capture, digest(spec), 'full', names)
    return capture


def registered_parts(parts, report, source_size):
    source, native = report['source_frame'], report['maquette_frame']
    factor = (native['sole_bottom'] - native['head_top']) / (source['sole_bottom'] - source['head_top'])
    transform = (factor, 0, native['ground_x'] - factor * source['ground_x'],
                 0, factor, native['head_top'] - factor * source['head_top'])
    return parts.transform(source_size, Image.Transform.AFFINE, transform, Image.Resampling.NEAREST)


def delivery(folder, capture=None):
    folder = Path(folder).resolve()
    recipe = json.loads((folder / 'measurements.json').read_text())
    spec = json.loads((folder / 'spec_native.json').read_text())
    capture = Path(capture) if capture else assemble(folder)
    proof_path = folder / 'proof/determinism/recipe_proof.json'
    proof = json.loads(proof_path.read_text()) if proof_path.exists() else {}
    determinism = determinism_matches(spec, proof)
    results, overlays = {}, []
    for view in ('front', 'rear'):
        source_path = PROJECT / recipe['sources'][view]
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != recipe['source_sha256'][view]:
            raise ValueError('Protected approved painting changed: ' + str(source_path))
        source = Image.open(source_path).convert('RGBA')
        raster = load_render(spec, capture, view)
        measured = deepcopy(spec)
        measured['fit'].update(recipe['fit'][view])
        report, comparison = measure(measured, source, raster=raster)
        report['per_part_coverage'] = {}
        parts = registered_parts(Image.open(capture / (view + '_parts.png')).convert('RGBA'), report, source.size)
        for index, name in enumerate(raster.names):
            visible = raster.owners == index
            solo = raster.masks[name]
            report['per_part_coverage'][name] = {'visible_pixels': int(visible.sum()),
                'solo_pixels': int(solo.sum()), 'visible_fraction_of_solo': float(visible.sum() / max(1, solo.sum())),
                'explicit_occlusion': recipe['occlusions'].get(view, {}).get(name)}
        missing = [name for name, values in report['per_part_coverage'].items()
                   if not values['solo_pixels'] or (not values['visible_pixels'] and not values['explicit_occlusion'])]
        report['checks']['required_part_coverage'] = not missing
        report['checks']['design_resolved'] = not recipe.get('unresolved_design')
        native = json.loads((capture / 'capture_checks.json').read_text())[view]
        report['checks']['native_capture'] = native['passed'] and native['geometry_unchanged']
        report['checks']['determinism_and_cache_replay'] = bool(determinism)
        report['empty_or_unexplained_parts'] = missing
        report['passed'] = all(report['checks'].values())
        report['inputs'] = {'source': recipe['sources'][view], 'source_sha256': recipe['source_sha256'][view],
                            'spec_hash': digest(spec), 'capture': str(capture.relative_to(PROJECT))}
        write(folder / 'proof' / (view + '_fit_report.json'), report)
        comparison.save(folder / 'proof' / (view + '_silhouette_comparison.png'))
        overlay = overlay_parts(source, parts, DELIVERY_DEFAULTS['overlay_opacity'])
        overlays.append(overlay)
        results[view] = report
    overlay = Image.new('RGBA', (sum(p.width for p in overlays), max(p.height for p in overlays)))
    for i, image in enumerate(overlays):
        overlay.paste(image, (i * image.width, 0))
    overlay.save(folder / 'proof' / 'fit_overlay.png')
    summary = {'schema': 1, 'id': spec['id'], 'passed': all(r['passed'] for r in results.values()),
               'spec_hash': digest(spec), 'views': results, 'overlay_opacity': DELIVERY_DEFAULTS['overlay_opacity'],
               'unresolved_design': recipe.get('unresolved_design', {})}
    write(folder / 'proof' / 'fit_report.json', summary)
    print('FITTED_DELIVERY: ' + ('PASS' if summary['passed'] else 'FAIL') + '; ' + spec['id'] + '; ' +
          '; '.join(view + '_iou=' + format(report['iou'], '.6f') for view, report in results.items()))
    return summary


def contact_sheet(folders, out, capture_subdir='proof'):
    sheets = [Image.open(Path(folder) / capture_subdir / 'fit_overlay.png').convert('RGBA') for folder in folders]
    width, height = max(p.width for p in sheets), max(p.height for p in sheets)
    row_height = height + DELIVERY_DEFAULTS['caption_height']
    columns = DELIVERY_DEFAULTS['contact_columns']
    rows = (len(sheets) + columns - 1) // columns
    result = Image.new('RGBA', (width * columns, row_height * rows), tuple(DELIVERY_DEFAULTS['contact_background']))
    draw = ImageDraw.Draw(result)
    for index, (folder, sheet) in enumerate(zip(folders, sheets)):
        left, top = index % columns * width, index // columns * row_height
        pad = DELIVERY_DEFAULTS['caption_padding']
        draw.text((left + pad, top + pad), Path(folder).name + ' | front / rear | parts 40%',
                  fill=DELIVERY_DEFAULTS['caption_colour'])
        result.alpha_composite(sheet, (left, top + DELIVERY_DEFAULTS['caption_height']))
    factor = DELIVERY_DEFAULTS['contact_scale']
    result.resize((result.width * factor, result.height * factor), Image.Resampling.NEAREST).save(out)
    print('FITTED_CONTACT_SHEET: ' + str(out))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--contact-sheet', type=Path)
    args = parser.parse_args()
    results = [delivery(folder) for folder in args.folders]
    if args.contact_sheet:
        contact_sheet(args.folders, args.contact_sheet)
    return 0 if all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
