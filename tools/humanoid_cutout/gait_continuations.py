"""Clip-scoped own-edge texel copies, on the garment's existing skin field.

The recipe stores coordinates, not new paint. Production copies its already
density-treated donor; clips without a recipe retain the original texture.
"""
import numpy as np
from PIL import Image

from maquette_motion.material_palette import interior_donors, rules


def active_recipe(layout, name, *, gait=False, clip=None):
    """The recipe a clip plays for one part, or None.

    A gait recipe's optional 'clips' list replaces gait-only playback (rr-22);
    'clip_continuations' declares per-clip recipes (rr-21) and wins on overlap.
    """
    if not gait:
        declared = layout.get('clip_continuations', {}).get(clip, {}).get(name)
        if declared is not None:
            return declared
    recipe = layout.get('gait_continuations', {}).get(name)
    if recipe is None:
        return None
    active = (isinstance(recipe['clips'], list) and clip in recipe['clips']) if 'clips' in recipe else gait
    return recipe if active else None


def texture(case, layout, part, *, gait=False, checks=False, clip=None):
    record = layout['proof_layers'][part['name']] if checks else part
    path = record['mask'] if checks else record['file']
    with Image.open(case / path) as image:
        result = np.asarray(image.convert('RGBA')).copy()
    recipe = active_recipe(layout, part['name'], gait=gait, clip=clip)
    if recipe:
        donor = next(p for p in layout['parts'] if p['name'] == recipe['donor'])
        with Image.open(case / donor['file']) as image:
            paint = np.asarray(image.convert('RGBA'))
        for x, y, u, v in recipe['texels']:
            result[y, x] = [255, 255, 0, 255] if checks else paint[v, u]
    return result


def nearest_donors(case, layout, part, targets):
    """Same exact squared-distance and row/column tie order as rr-05 bleed."""
    donor = next(p for p in layout['parts']
                 if p['logical_part'] == part['logical_part'] and not p.get('hidden_material'))
    with Image.open(case / donor['file']) as image:
        paint = interior_donors(np.asarray(image.convert('RGBA')), rules(case, layout['facing']))
    v, u = np.nonzero(paint[..., 3])
    points = np.column_stack((u, v)) + donor['offset']
    result = []
    for x, y in sorted(targets, key=lambda p: (p[1], p[0])):
        target = np.array([x, y]) + part['offset']
        index = np.argmin(np.sum((points - target) ** 2, axis=1))
        result.append([int(x), int(y), int(u[index]), int(v[index])])
    return {'donor': donor['name'], 'texels': result}


def errors(case, layout):
    tables = [layout.get('gait_continuations', {})]
    tables += list(layout.get('clip_continuations', {}).values())
    parts = {p['name']: p for p in layout['parts']}
    result = []
    for name, recipe in [entry for recipes in tables for entry in recipes.items()]:
        if name not in parts or recipe.get('donor') not in parts:
            result.append('gait continuation: unknown part/donor: ' + name)
            continue
        part = parts[name]
        source = texture(case, layout, part)
        targets = [(x, y) for x, y, _, _ in recipe['texels']]
        if (len(set(targets)) != len(targets) or any(
                x < 0 or y < 0 or x >= source.shape[1] or y >= source.shape[0]
                or source[y, x, 3] for x, y in targets)):
            result.append('gait continuation: must add only transparent source texels: ' + name)
        elif {k: v for k, v in recipe.items() if k != 'clips'} != nearest_donors(case, layout, part, targets):
            result.append('gait continuation: differs from own non-outline edge texels: ' + name)
        if 'clips' in recipe:
            from cutout_pipeline.cases import read_json
            data = read_json(case / 'compiled_motion.json')
            if (not isinstance(recipe['clips'], list) or not recipe['clips'] or
                    set(recipe['clips']) - (set(data['clips']) - {'idle', 'rest'})):
                result.append('action continuation: expected declared action clips, excluding rest/idle: ' + name)
    return result
