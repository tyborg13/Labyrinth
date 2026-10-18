"""Maquette-first review: current 1024 clays, proportion guidance and ownership.

No retouching or figure-dependent resizing. Lancer reference pixels are copied
to the contact sheet at 1:1, alongside the two current native camera captures.
"""
import argparse
import csv
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.fit_delivery import registered_parts, determinism_matches, overlay_parts
from spec.art_identity.maquettes.fitting import measure


QUALITY_DEFAULTS = {'size': 1024, 'caption_height': 28, 'background': [24, 24, 24, 255],
                    'caption_colour': 'white', 'caption_font': 'Pillow default', 'padding': 4,
                    'overlay_opacity': .4, 'contact_box_colour': [255, 80, 80, 255],
                    'contact_box_width': 3, 'contact_box_padding': 8}


def write(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--lancer', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--capture-subdir', default='proof/quality_r2')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    size, header = QUALITY_DEFAULTS['size'], QUALITY_DEFAULTS['caption_height']
    sheet = Image.new('RGBA', ((len(args.folders) + 1) * size, 2 * (size + header)), tuple(QUALITY_DEFAULTS['background']))
    draw = ImageDraw.Draw(sheet)
    table = ['| Figure | Front IoU (≥0.70) | Rear IoU (≥0.65) | Native geometry | Visible part-views |',
             '|---|---:|---:|---|---:|']
    results = {}
    coverage_rows = []
    for column, folder in enumerate(args.folders):
        recipe = json.loads((folder / 'measurements.json').read_text())
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        spec = compile_recipe(recipe)
        capture = folder / args.capture_subdir
        manifest = read_manifest(capture, digest(spec), ('preview', 'full'))
        report = json.loads((capture / 'build_report.json').read_text())
        if report['spec_hash'] != digest(spec) or spec['ortho_scale'] != 2.4:
            raise ValueError('Stale capture or camera scale differs from Lancer')
        proof_path = capture / 'determinism/recipe_proof.json'
        if not proof_path.exists():
            proof_path = capture / 'recipe_proof.json'
        proof = json.loads(proof_path.read_text()) if proof_path.exists() else {}
        determinism = (determinism_matches(spec, proof) and
            report['combined_mesh_hash'] == proof.get('combined_mesh_hashes', {}).get('cold'))
        capture_checks = json.loads((capture / 'capture_checks.json').read_text())
        invariant = capture_checks.get('spec_hash') == digest(spec) and capture_checks.get('geometry_unchanged', False)
        contacts_path = capture / 'contact_diagnostic.json'
        contacts = json.loads(contacts_path.read_text()) if contacts_path.exists() else {}
        contact_sheet = Image.new('RGBA', (2 * size, size + header), tuple(QUALITY_DEFAULTS['background']))
        contact_draw = ImageDraw.Draw(contact_sheet)
        views, visible_total = {}, 0
        overlays = Image.new('RGBA', (512, 256))
        for row, view in enumerate(('front', 'rear')):
            source_path = PROJECT / recipe['sources'][view]
            if hashlib.sha256(source_path.read_bytes()).hexdigest() != recipe['source_sha256'][view]:
                raise ValueError('Protected identity reference changed')
            source = Image.open(source_path).convert('RGBA')
            raster = load_render(spec, capture, view)
            measured = deepcopy(spec)
            measured['fit'].update(recipe['fit'][view])
            measured['unresolved_design'] = deepcopy(recipe.get('unresolved_design', {}))
            fit, comparison = measure(measured, source, raster=raster)
            fit['proportion_guidance_passed'] = fit['iou'] >= recipe['fit'][view]['gate']['iou_min']
            fit['visible_part_pixels'] = {name: int((raster.owners == i).sum()) for i, name in enumerate(raster.names)}
            if manifest['mode'] == 'full':
                from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
                fit['per_part_coverage'] = part_coverage(spec,raster,Image.open(capture/(view+'_parts.png')).convert('RGBA'))
                fit['unclipped_required_solos'] = not any(v['clipped_at_canvas'] for v in fit['per_part_coverage'].values())
                for name, values in fit['per_part_coverage'].items():
                    coverage_rows.append([folder.name, view, name, values['visible_pixels'], values['solo_pixels'],
                                          values['visible_fraction_of_solo'], values['clipped_at_canvas'],
                                          values['pure_owner_pixels'],values['depth_tested_owner_pixels']])
            missing = [name for name, count in fit['visible_part_pixels'].items()
                       if (not count or ('per_part_coverage' in fit and not fit['per_part_coverage'][name]['pure_owner_pixels']))
                       and not recipe['occlusions'].get(view, {}).get(name)]
            fit['missing_unoccluded_parts'] = missing
            visible_total += len(raster.names) - len(missing)
            write(capture / (view + '_proportion_report.json'), fit)
            comparison.save(capture / (view + '_proportion_comparison.png'))
            parts = registered_parts(Image.open(capture / (view + '_parts.png')).convert('RGBA'), fit, source.size)
            overlays.paste(overlay_parts(source, parts, QUALITY_DEFAULTS['overlay_opacity']), (row * 256, 0))
            views[view] = fit
            clay = Image.open(capture / (view + '_clay.png')).convert('RGBA')
            if clay.size != (size, size):
                raise ValueError('Clay must be native 1024 square')
            sheet.alpha_composite(clay, (column * size, row * (size + header) + header))
            contact_sheet.alpha_composite(clay, (row * size, header))
            contact_draw.text((row * size + 4, 4), folder.name + ' / ' + view + ' / geometric contacts',
                              fill=QUALITY_DEFAULTS['caption_colour'])
            if contacts.get('spec_hash') == digest(spec):
                for piece, views_box in contacts.get('view_bboxes_px', {}).items():
                    x0, y0, x1, y1 = views_box[view]
                    pad = QUALITY_DEFAULTS['contact_box_padding']
                    box = [max(0, x0 - pad) + row * size, max(0, y0 - pad) + header,
                           min(size - 1, x1 + pad) + row * size, min(size - 1, y1 + pad) + header]
                    contact_draw.rectangle(box, outline=tuple(QUALITY_DEFAULTS['contact_box_colour']),
                                           width=QUALITY_DEFAULTS['contact_box_width'])
            draw.text((column * size + 4, row * (size + header) + 4), folder.name + ' / ' + view,
                      fill=QUALITY_DEFAULTS['caption_colour'])
        overlays.save(capture / 'fit_overlay.png', optimize=True, compress_level=9)
        # Always replace the diagnostic sheet: a clean current capture must
        # never leave a previous failed model's contact boxes behind.
        contact_sheet.save(capture / 'collision_overlay.png')
        table.append(f"| {folder.name} | {views['front']['iou']:.6f} | {views['rear']['iou']:.6f} | {'PASS' if report['passed'] else 'FAIL'} | {visible_total}/{2 * len(spec['labels'])} |")
        acceptance_path = capture / 'director_acceptance.json'
        acceptance = json.loads(acceptance_path.read_text()) if acceptance_path.exists() else {}
        issues = {key: value for key, value in recipe.get('implementation_issues', {}).items()
                  if key not in acceptance.get('resolved_implementation_issues', {})}
        results[folder.name] = {'spec_hash': digest(spec), 'capture_manifest': manifest,
            'build_report': report, 'views': views, 'unresolved_design': recipe.get('unresolved_design', {}),
            'implementation_issues': issues, 'director_acceptance': acceptance,
            'visual_quality_certified': False,
            'determinism': proof, 'capture_matches_current_cold_proof': determinism}
        results[folder.name]['capture_geometry_unchanged'] = invariant
        results[folder.name]['capture_checks'] = capture_checks
        results[folder.name]['contact_diagnostic'] = contacts
    for row, view in enumerate(('front', 'rear')):
        clay = Image.open(args.lancer / (view + '_clay.png')).convert('RGBA')
        if clay.size != (size, size):
            raise ValueError('Lancer reference must be native 1024 square')
        sheet.alpha_composite(clay, (len(args.folders) * size, row * (size + header) + header))
        draw.text((len(args.folders) * size + 4, row * (size + header) + 4), 'Frostglass Lancer r3 / ' + view,
                  fill=QUALITY_DEFAULTS['caption_colour'])
    sheet.convert('RGB').save(args.out / 'clay_comparison_lancer_r3.png', optimize=True, compress_level=9)
    from spec.art_identity.maquettes.blender.fit_delivery import contact_sheet
    contact_sheet(args.folders, args.out / 'fit_overlay_contact_sheet.png', args.capture_subdir)
    write(args.out / 'quality_results.json', results)
    (args.out / 'fit_table.md').write_text('\n'.join(table) + '\n')
    with (args.out / 'per_part_coverage.csv').open('w', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['figure', 'view', 'part', 'visible_pixels', 'solo_pixels', 'visible_fraction_of_solo', 'clipped_at_canvas',
                         'pure_owner_pixels','depth_tested_owner_pixels'])
        writer.writerows(coverage_rows)
    print('\n'.join(table))
    passed = all(r['build_report']['passed'] and r['capture_matches_current_cold_proof'] and r['capture_geometry_unchanged'] and all(v['proportion_guidance_passed'] and
        not v['missing_unoccluded_parts'] and v.get('unclipped_required_solos', True)
        for v in r['views'].values()) for r in results.values())
    design_todos = {name: r['unresolved_design'] for name, r in results.items() if r['unresolved_design']}
    implementation_todos = {name: r['implementation_issues'] for name, r in results.items() if r['implementation_issues']}
    print('MAQUETTE_TECHNICAL_GATES: ' + ('PASS' if passed else 'FAIL'))
    print('MAQUETTE_DESIGN_FIELDS: ' + ('TODO' if design_todos else 'COMPLETE'))
    print('MAQUETTE_IMPLEMENTATION_FIELDS: ' + ('TODO' if implementation_todos else 'COMPLETE'))
    print('MAQUETTE_QUALITY_DELIVERY: ' + ('INCOMPLETE_IMPLEMENTATION' if passed and implementation_todos else
          'INCOMPLETE_DESIGN' if passed and design_todos else 'PASS' if passed else 'FAIL'))
    return 0 if passed and not design_todos and not implementation_todos else 1


if __name__ == '__main__':
    raise SystemExit(main())
