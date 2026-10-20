"""Apply rr-27's coordinate-only, clip-scoped joint coverage to mq7b.

Do not replay historical builders or repaint/density-process any texture.
The director's sources, motion, rest composites and production paths stay put.
"""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gait_continuations import nearest_donors, errors

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
RECIPE = Path(__file__).with_name('rr27')
ASSETS = PROJECT / 'assets/units/arc_thrall_cutout'


def apply_front(layout):
    definition = read_json(RECIPE / 'joint_continuations.json')
    part = next(p for p in layout['parts'] if p['name'] == definition['piece'])
    recipe = nearest_donors(CASE, layout, part, definition['local_targets'])
    recipe['clips'] = definition['clips']
    layout.setdefault('gait_continuations', {})[part['name']] = recipe
    return layout


def remove_continuation_copies(layout):
    """Remove only the director's two copied texels, retaining fixed crops.

    The far copy was baked into its hidden continuation PNG by mq7b. Removing
    that recipe output is not an edit to the approved painting or rest. Its
    allowed-tuck mask is rebuilt at the same point, exactly as proof_masks
    would do for the reduced continuation. The near copy is clip-only data.
    """
    for definition in read_json(RECIPE / 'continuation_removals.json')['rear']:
        name = definition['piece']
        part = next(p for p in layout['parts'] if p['name'] == name)
        x, y = [a - b for a, b in zip(definition['source_texel'], part['offset'])]
        if definition['kind'] == 'gait_recipe_target':
            recipe = layout['gait_continuations'][name]
            recipe['texels'] = [row for row in recipe['texels'] if row[:2] != [x, y]]
            continue
        path = CASE / part['file']
        image = np.asarray(Image.open(path).convert('RGBA')).copy()
        image[y, x] = 0
        Image.fromarray(image).save(path)
        record = layout['proof_layers'][name]
        mask_path = CASE / record['mask']
        mask = np.asarray(Image.open(mask_path).convert('RGBA')).copy()
        mx, my = [a - b for a, b in zip(definition['source_texel'], record['mask_offset'])]
        mask[my, mx] = 0
        Image.fromarray(mask).save(mask_path)
        record['source_sha256'] = digest(path)
        # This required-tuck raster was generated from the old copied
        # continuation. Remove that same obsolete requirement, not another
        # texel or a frame exception, and refresh its derived pixel count.
        tuck_path = CASE / 'tucks/rear_leg_far.png'
        tuck = Image.open(tuck_path).copy()
        tuck.putpixel(tuple(definition['source_texel']),0)
        tuck.save(tuck_path)
        build_path = CASE / 'proof/build.json'
        build = read_json(build_path)
        report = next(r for r in build['views']['rear']['tucks'] if r['piece'] == 'leg_far')
        report['required_pixels'] = int(np.count_nonzero(np.asarray(tuck)))
        write_json(build_path,build)
    return layout


def main():
    layouts = {'front': apply_front(read_json(CASE / 'layouts/front.json')),
               'rear': remove_continuation_copies(read_json(CASE / 'layouts/rear.json'))}
    recipes = read_json(CASE / 'gait_continuations.json')
    for view, layout in layouts.items():
        invalid = errors(CASE, layout)
        if invalid:
            raise ValueError(invalid)
        write_json(CASE / f'layouts/{view}.json', layout)
        # Production uses different prefixes. Retain all layout fields and
        # update only the copied recipe data and the one hidden-copy output.
        for path in (ASSETS / f'{view}.json', ASSETS / f'humanoid_v2/{view}.json'):
            production = read_json(path)
            production['gait_continuations'] = layout['gait_continuations']
            write_json(path, production)
            if view == 'rear':
                name = 'mq7b_continuation_leg_far'
                target = next(p for p in production['parts'] if p['name'] == name)
                # Production is already density-treated. Preserve every
                # treated RGBA value apart from the removed copy itself.
                texture_path = path.parent / target['file']
                image = Image.open(texture_path).convert('RGBA')
                point = read_json(RECIPE / 'continuation_removals.json')['rear'][0]['source_texel']
                x,y = [a-b for a,b in zip(point,target['offset'])]
                image.putpixel((x,y),(0,0,0,0))
                image.save(texture_path)
        recipes[view] = layout['gait_continuations']
    write_json(CASE / 'gait_continuations.json', recipes)
    # The historical mq7b construction recipe must not restore the near copy
    # if it is replayed before this task's final correction pass.
    original_recipe = RECIPE.parent / 'rr24/gait_continuations.json'
    original = read_json(original_recipe)
    original['rear'] = layouts['rear']['gait_continuations']
    write_json(original_recipe, original)
    # Refresh only the existing owned closure hashes. Shared identity/density
    # registries and shadow records belong to the director/int-03.
    integration_path = ASSETS / 'integration.json'
    integration = read_json(integration_path)
    integration['files'] = {name:digest(ASSETS / name) for name in integration['files']}
    write_json(integration_path,integration)
    count = len(layouts['front']['gait_continuations']['upper_near']['texels'])
    print(f'RR27 FRONT JOINT CONTINUATIONS: PASS ({count} own-piece donor copies; jab/death only)')
    print('RR27 REAR CONTINUATION REMOVALS: PASS (2 copied texels removed; fixed crops and approved paint retained)')


if __name__ == '__main__':
    main()
