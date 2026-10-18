"""Reproduce mq-06's transform, landmark and pixel evidence without Blender."""
from copy import deepcopy
import csv
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))
sys.path.insert(0, str(PROJECT / 'tests'))

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.fitting import measure
from spec.art_identity.maquettes.raster import camera, project
from test_maquette_rear_turn import deliveries, observations

PROOF_DEFAULTS = {'sheet_cell_px': 1024, 'painting_enlargement': 4,
                  'sheet_columns': ['front clay', 'old rear clay', 'fresh 180-degree rear (defect reproduced)',
                                    'old approved rear painting', 'fresh rear part map']}


def main():
    output = Path(__file__).resolve().parent
    figure = output.parent
    recipe = json.loads((figure / 'measurements.json').read_text())
    spec = compile_recipe(recipe)
    transforms = {}
    for view in ('front', 'rear'):
        matrix, target, basis, scale = camera(spec, view)
        transforms[view] = {'object_to_world': matrix.tolist(), 'target': target.tolist(),
                            'camera_basis': basis.tolist(), 'ortho_scale': scale,
                            'rotation_determinant': float(np.linalg.det(matrix[:3, :3]))}
    landmarks = {name: {'body': spec['joints'][name],
                       'measured_pair': recipe['joints_px'][name],
                       'projected_pair': {view: project(spec, spec['joints'][name], view, 256)[:2].tolist()
                                          for view in ('front', 'rear')}}
                 for name in ('ankle_near', 'ankle_far', 'foot_tip_near', 'foot_tip_far')}
    measured = deepcopy(spec)
    measured['fit'].update(recipe['fit']['rear'])
    raster = load_render(spec, figure / 'delivery', 'rear')
    with Image.open(PROJECT / recipe['sources']['rear']) as image:
        fit, _ = measure(measured, image.convert('RGBA'), raster=raster)
    with Image.open(figure / 'delivery/rear_parts.png') as image:
        coverage = part_coverage(spec, raster, image.convert('RGBA'))
    result = {'transforms': transforms, 'landmarks': landmarks,
              'far_minus_near_ankle_height_m': spec['joints']['ankle_far'][2] - spec['joints']['ankle_near'][2],
              'rear_iou': fit['iou'], 'rear_per_part_coverage': coverage,
              'delivered_pixels': {str(folder.relative_to(PROJECT)): observations(folder) for folder in deliveries()},
              'recipe_sha256': hashlib.sha256((figure / 'measurements.json').read_bytes()).hexdigest(),
              'floor_contact_decision': 'Resolved by mq-06 feedback 1: lower far foot and far hem along the front camera ray. Feedback 2 front v2 gate passed on its diagnostic. Feedback 3 now clears native collision checks, but its normal fallback fails the front alpha/robe-union gate; delivery remains unchanged. See feedback3/README.md.'}
    baseline = output / 'baseline'
    if (baseline / 'rear/capture_checks.json').is_file():
        fresh_build = json.loads((baseline / 'build/build_report.json').read_text())
        delivered_build = json.loads((figure / 'delivery/build_report.json').read_text())
        checks = json.loads((baseline / 'rear/capture_checks.json').read_text())
        comparisons = {}
        for path in sorted((baseline / 'rear').glob('rear_*.png')):
            with Image.open(path) as image:
                fresh = np.array(image.convert('RGBA'))
            with Image.open(figure / 'delivery' / path.name) as image:
                old = np.array(image.convert('RGBA'))
            comparisons[path.name] = {
                'alpha_equal': bool(np.array_equal(old[..., 3], fresh[..., 3])),
                'visible_rgba_equal': bool(np.array_equal(old[old[..., 3] > 0], fresh[old[..., 3] > 0])),
                'native_file_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        result['fresh_reproduction'] = {'capture_checks': checks,
            'mesh_hash_matches_delivery': fresh_build['combined_mesh_hash'] == delivered_build['combined_mesh_hash'],
            'mesh_hash': fresh_build['combined_mesh_hash'], 'images': comparisons,
            'delivery_image_sha256': {name: hashlib.sha256((figure / 'delivery' / name).read_bytes()).hexdigest()
                                      for name in comparisons}}
        cell = PROOF_DEFAULTS['sheet_cell_px']
        paths = [figure / 'delivery/front_clay.png', figure / 'delivery/rear_clay.png',
                 baseline / 'rear/rear_clay.png', PROJECT / recipe['sources']['rear'],
                 baseline / 'rear/rear_parts.png']
        sheet = Image.new('RGBA', (len(paths) * cell, cell))
        for index, path in enumerate(paths):
            with Image.open(path) as image:
                image = image.convert('RGBA')
                if index == 3:
                    factor = PROOF_DEFAULTS['painting_enlargement']
                    image = image.resize((image.width * factor, image.height * factor), Image.Resampling.NEAREST)
                if index != 3 and image.size != (cell, cell):
                    raise ValueError('Proof sheet requires native 1024 cells, except the explicitly enlarged painting')
                sheet.alpha_composite(image, (index * cell + (cell - image.width) // 2,
                                              (cell - image.height) // 2))
        sheet.save(output / 'reproduction_sheet.png', optimize=True)
        result['sheet'] = PROOF_DEFAULTS
        result['fresh_reproduction']['sheet_sha256'] = hashlib.sha256((output / 'reproduction_sheet.png').read_bytes()).hexdigest()
        (output / 'native_reproduction.json').write_text(json.dumps(result['fresh_reproduction'], indent=2) + '\n')
    elif (output / 'native_reproduction.json').is_file():
        native = json.loads((output / 'native_reproduction.json').read_text())
        for name, expected in native['delivery_image_sha256'].items():
            if hashlib.sha256((figure / 'delivery' / name).read_bytes()).hexdigest() != expected:
                raise ValueError('Recorded baseline reproduction is stale: ' + name)
        sheet_path = output / 'reproduction_sheet.png'
        if sheet_path.exists():
            if hashlib.sha256(sheet_path.read_bytes()).hexdigest() != native['sheet_sha256']:
                raise ValueError('Recorded reproduction sheet is stale')
        else:
            archive = json.loads((figure / 'discarded_proof_sha256.json').read_text())['files']
            if not any(name == 'rear_turn/reproduction_sheet.png' and value == native['sheet_sha256']
                       for name, _, value in archive):
                raise ValueError('Discarded reproduction sheet hash is missing')
        result['fresh_reproduction'], result['sheet'] = native, PROOF_DEFAULTS
    with (output / 'rear_coverage_before.csv').open('w', newline='') as stream:
        fields = ['part', 'visible_pixels', 'solo_pixels', 'pure_owner_pixels', 'recorded_occlusion']
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for name, values in coverage.items():
            writer.writerow({'part': name, **{key: values[key] for key in fields[1:4]},
                             'recorded_occlusion': recipe['occlusions']['rear'].get(name, '')})
    (output / 'root_cause.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'MQ06_ROOT_CAUSE: rear determinant={transforms["rear"]["rotation_determinant"]}; '
          f'far ankle raised={result["far_minus_near_ankle_height_m"]:.9f} m; rear_iou={fit["iou"]:.9f}')


if __name__ == '__main__':
    main()
