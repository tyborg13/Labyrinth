"""Clip-scoped own-edge texel copies, on the garment's existing skin field.

The recipe stores coordinates, not new paint. Production copies its already
density-treated donor; clips without a recipe retain the original texture.
"""
import numpy as np
from PIL import Image

from maquette_motion.material_palette import interior_donors, rules, luma, outline_class


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
        original = np.asarray(image.convert('RGBA'))
        paint = interior_donors(original, rules(case, layout['facing']))
    rule = part.get('continuation_donor_rule', 'nearest')
    if rule not in ('nearest', 'same_row'):
        raise ValueError('Invalid continuation donor rule')
    margin = part.get('continuation_interior_margin_px', 0)
    if type(margin) is not int or margin < 0:
        raise ValueError('Invalid continuation donor interior margin')
    if margin:
        from maquette_motion.silhouette import dilate
        # Pad the crop: texture boundaries are also rest-outline boundaries.
        air = np.pad(original[...,3]==0, margin, constant_values=True)
        paint[dilate(air, margin)[margin:-margin,margin:-margin]] = 0
        boundary=(original[...,3]>0) & dilate(np.pad(original[...,3]==0,1,constant_values=True),1)[1:-1,1:-1]
        outline=boundary | outline_class(original,rules(case,layout['facing']))
        # Row extensions use the declared distance inside the rest outline.
        # Legacy nearest fills retain their additional ink-band clearance.
        if rule == 'nearest':paint[dilate(outline,margin)] = 0
    declared=donor.get('continuation_donor_uvs')
    if declared is not None:
        legal=np.zeros(paint.shape[:2],bool)
        for point in declared:
            if (not isinstance(point,list) or len(point)!=2 or any(type(n) is not int for n in point)):
                raise ValueError('Invalid declared continuation donor coordinate')
            u,v=point
            if not (0<=u<paint.shape[1] and 0<=v<paint.shape[0]) or not original[v,u,3]:
                raise ValueError('Declared continuation donor outside its approved piece')
            legal[v,u]=True
        paint[~legal]=0
    minimum = part.get('continuation_min_luma')
    if minimum is not None:
        if type(minimum) not in (int, float) or not np.isfinite(minimum) or minimum < 0:
            raise ValueError('Invalid continuation donor luminance minimum')
        paint[luma(paint) < minimum] = 0
    if not (paint[..., 3] > 0).any():
        raise ValueError('No approved continuation donors')
    v, u = np.nonzero(paint[..., 3])
    points = np.column_stack((u, v)) + donor['offset']
    result = []
    for x, y in sorted(targets, key=lambda p: (p[1], p[0])):
        target = np.array([x, y]) + part['offset']
        candidates = np.flatnonzero(points[:, 1] == target[1]) if rule == 'same_row' else np.arange(len(points))
        if not len(candidates):
            raise ValueError('No approved same-row continuation donors')
        index = candidates[np.argmin(np.sum((points[candidates] - target) ** 2, axis=1))]
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
