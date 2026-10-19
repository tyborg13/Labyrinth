"""Re-cut the final mq7b paint on the frozen gait-01 Thrall geometry.

This is pixel ownership, never new paint. The frozen closure retains every
joint, skin field, hidden joint cap, presentation anchor and motion byte.
"""
from copy import deepcopy
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

from rr11_build import (PROJECT, CASE, ASSETS, PIECES, BONES, store, proof_masks,
                        read_json, write_json, digest, promote, skin_layer)
from tools.humanoid_cutout.anatomy import load as load_anatomy
from tools.humanoid_cutout.gait_continuations import nearest_donors
from tools.humanoid_cutout.gait_continuations import errors as gait_errors
from tools.humanoid_cutout.underlays import distinct_depths
from tools.humanoid_cutout.tucks import required_tuck
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules

RECIPE = PROJECT / 'experiments/cutouts/arc_thrall/rr24'
BASELINE = RECIPE / 'baseline'
RESIDUE_MARGIN = 12  # Director's existing chroma-key residue rule.
RESIDUE_RATIO = 1.5


def residue(image):
    rgb = image[..., :3].astype(int)
    other = np.maximum(rgb[..., 0], rgb[..., 2])
    return ((image[..., 3] > 0) & (rgb[..., 1] >= other + RESIDUE_MARGIN)
            & (rgb[..., 1] >= RESIDUE_RATIO * other))


def clean_residue(image, donors=None):
    result = image.copy()
    source = image if donors is None else donors
    ys, xs = np.nonzero((source[..., 3] > 0) & ~residue(source))
    corrections = []
    for y, x in zip(*np.nonzero(residue(image))):
        i = np.argmin((xs - x) ** 2 + (ys - y) ** 2)
        result[y, x] = source[ys[i], xs[i]]
        corrections.append({'target': [int(x), int(y)], 'donor': [int(xs[i]), int(ys[i])]})
    return result, corrections


def polygon(points):
    mask = Image.new('1', (255, 255))
    ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=1)
    return np.asarray(mask).copy()


def visible_layers(view, paint):
    layout = read_json(BASELINE / f'layouts/{view}.json')
    visible = {name: np.zeros_like(paint) for name in PIECES}
    assigned = np.zeros(paint.shape[:2], dtype=bool)
    for part in layout['parts']:
        if part.get('hidden_material'): continue
        record = layout['proof_layers'][part['name']]
        checks = np.zeros_like(paint)
        image = np.asarray(Image.open(BASELINE / record['mask']).convert('RGBA'))
        x, y = record['mask_offset']
        checks[y:y + image.shape[0], x:x + image.shape[1]] = image
        mask = (checks[..., 0] > 0) & (checks[..., 1] == 0) & (paint[..., 3] > 0)
        visible[part['logical_part']][mask] = paint[mask]
        assigned |= mask
    # New silhouette pixels inherit the nearest old anatomical surface.
    # The traced head/collar/skirt contours below then supply semantic ownership.
    yy, xx = np.nonzero(assigned)
    for y, x in zip(*np.nonzero((paint[..., 3] > 0) & ~assigned)):
        index = np.argmin((xx - x) ** 2 + (yy - y) ** 2)
        owner = next(n for n, im in visible.items() if im[yy[index], xx[index], 3])
        visible[owner][y, x] = paint[y, x]
    recipe = read_json(RECIPE / 'ownership.json')[view]
    for contour, owner in [('head', 'head'), ('collar', 'torso'), ('skirt', 'loincloth')]:
        mask = polygon(recipe[contour]) & (paint[..., 3] > 0)
        # Clear the old head/skirt assignment before tracing the entire new one.
        if contour in ('head', 'skirt'):
            old_owner = 'head' if contour == 'head' else 'loincloth'
            remainder = (visible[old_owner][..., 3] > 0) & ~mask
            destination = 'torso' if contour == 'head' else None
            if destination:
                visible[destination][remainder] = paint[remainder]
            else:
                # Old cloth masks include source-label fringe islands. Keep
                # their anatomical ownership from the frozen corrected cut.
                from tools.humanoid_cutout.silhouette_gates import segment_distance
                for y, x in zip(*np.nonzero(remainder)):
                    def distance(name):
                        side = name[4:]
                        joints = [np.asarray(layout['joints'][bone + '_' + side]['position'])
                                  for bone in ('thigh', 'shin', 'foot')]
                        return min(float(segment_distance(np.asarray([[x,y]]),a,b)[0])
                                   for a,b in zip(joints,joints[1:]))
                    side = min(('leg_near', 'leg_far'), key=distance)
                    visible[side][y, x] = paint[y, x]
            visible[old_owner][:] = 0
        for name in visible:
            visible[name][mask] = paint[mask] if name == owner else 0
    # Pixel stairs on the contour belong to the adjoining connected surface.
    # Record exact transfers below so source ownership is independently
    # auditable. No colour heuristic is used to infer clothing from skin.
    from maquette_motion.silhouette import components, dilate
    for name in ('torso', 'leg_near', 'leg_far'):
        labels, groups = components(visible[name][..., 3] > 0, 8)
        for label, size in groups[1:]:
            island = labels == label
            neighbours = dilate(island, 1, grid_distance=True) & ~island
            candidates = {n: int((neighbours & (im[..., 3] > 0)).sum())
                          for n, im in visible.items() if n != name}
            owner = max(candidates, key=candidates.get)
            if not candidates[owner]: continue
            visible[owner][island] = paint[island]
            visible[name][island] = 0
    return visible


def build_view(view):
    anatomy = load_anatomy(CASE)
    old = read_json(BASELINE / f'layouts/{view}.json')
    layout = deepcopy(old)
    job = PROJECT / f'spec/art_identity/jobs/arc_thrall/mq7b_{view}'
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(job / name, CASE / 'source' / view / name)
    paint = np.asarray(Image.open(job / 'processed.png').convert('RGBA'))
    visible = visible_layers(view, paint)
    raw_composed = np.zeros_like(paint)
    corrections = {}
    for name, image in visible.items():
        target = RECIPE / 'raw' / view / (name + '.png')
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(image).save(target)
        selected = image[..., 3] > 0
        raw_composed[selected] = image[selected]
        visible[name], corrections[name] = clean_residue(image)
    raw_mismatch = int(np.any(raw_composed != paint, axis=-1).sum())
    write_json(RECIPE / f'{view}_residue_corrections.json', corrections)
    # Raw authoring is byte/pixel bound independently of cleaned presentation.
    presentation = np.zeros_like(paint)
    for image in visible.values():
        mask = image[..., 3] > 0
        presentation[mask] = image[mask]
    Image.fromarray(presentation).save(CASE / 'source' / view / 'presentation.png')
    layout['raw_rest_source'] = f'source/{view}/processed.png'
    layout['rest_source'] = f'source/{view}/presentation.png'
    hidden = {n: np.zeros_like(paint) for n in PIECES}
    for part in old['parts']:
        layer = source_pixels(BASELINE, part)
        checks = np.zeros_like(paint)
        record = old['proof_layers'][part['name']]
        check = np.asarray(Image.open(BASELINE / record['mask']).convert('RGBA'))
        x, y = record['mask_offset']
        checks[y:y + check.shape[0], x:x + check.shape[1]] = check
        mask = checks[..., 1] > 0
        hidden[part['logical_part']][mask] = layer[mask]
    for name, image in hidden.items():
        hidden[name], _ = clean_residue(image, visible[name])
    # Skin uncovered by the new skirt remains on each leg's own skin field.
    # Extend only beneath the approved skirt, using that thigh's own texels.
    for name in ('leg_near', 'leg_far'):
        original = source_pixels(BASELINE, next(p for p in old['parts'] if p['name'] == name))
        domain = ((original[..., 3] > 0) & (visible['loincloth'][..., 3] > 0)) | (hidden[name][..., 3] > 0)
        from maquette_motion.silhouette import dilate
        solo = np.asarray(Image.open(CASE / f'{view}_baseline/registered/{view}_solo_thigh_{name[4:]}.png').convert('RGBA'))[...,3] > 128
        domain |= (dilate(solo, anatomy['joint_continuations']['depth_px'])
                   & (visible['loincloth'][...,3] > 0))
        hidden[name] = edge_texels(visible[name], domain, rules(CASE, view))
    # Neck continuation is skin, never part of the iron collar. Retain its
    # existing coverage, but take donor texels from the newly cut head.
    hidden['head'] = edge_texels(visible['head'], hidden['head'][..., 3] > 0, rules(CASE, view))
    from maquette_motion.silhouette import dilate
    neck = (dilate(visible['head'][..., 3] > 0, anatomy['joint_continuations']['depth_px'])
            & (visible['torso'][..., 3] > 0))
    continuation = edge_texels(visible['head'], neck, rules(CASE, view))
    hidden['head'][neck] = continuation[neck]
    collar_tuck = (dilate(visible['torso'][...,3] > 0, anatomy['joint_continuations']['depth_px'])
                   & (visible['head'][...,3] > 0))
    continuation = edge_texels(visible['torso'], collar_tuck, rules(CASE,view))
    hidden['torso'][collar_tuck] = continuation[collar_tuck]
    reports = []
    for name, recipe in anatomy['tucks']['pieces'].items():
        required = required_tuck(name, visible, layout['joints'], anatomy['tucks'],
                                 continuation=hidden[name][..., 3] > 0)
        missing = required & (hidden[name][..., 3] == 0) & (visible[name][..., 3] == 0)
        fill = edge_texels(visible[name], missing, rules(CASE, view))
        hidden[name][missing] = fill[missing]
        hidden[name][visible[name][..., 3] > 0] = 0
        path = CASE / f'tucks/{view}_{name}.png'
        Image.fromarray(required.astype('uint8') * 255).save(path)
        supplied = (hidden[name][..., 3] > 0) | (visible[name][..., 3] > 0)
        reports.append({'piece': name, 'minimum_px': recipe['depth_px'], 'cover': recipe['covers'],
            'required_mask': str(path.relative_to(CASE)), 'required_pixels': int(required.sum()),
            'missing_pixels': int((required & ~supplied).sum())})
    # Preserve every existing draw layer/crop; only the rigid head may need a
    # larger crop for its newly owned neck. Its presentation anchor is fixed.
    parts, meshes = [], []
    depths = {p['name']: p['z_index'] for p in old['parts']}
    depths['loincloth'] = max(depths['loincloth'], depths['leg_near'] + 1, depths['leg_far'] + 1)
    allocated = {n: np.zeros(paint.shape[:2], dtype=bool) for n in PIECES}
    for original in old['parts']:
        part = deepcopy(original)
        name, garment = part['name'], part['logical_part']
        image = np.zeros_like(paint)
        if part.get('hidden_material'):
            original_pixels = source_pixels(BASELINE, part)
            mask = (original_pixels[..., 3] > 0) & (paint[..., 3] > 0)
            image[mask] = hidden[garment][mask]
            allocated[garment] |= mask
        else:
            image = visible[garment].copy()
        bounds = list(part['bbox'])
        ys, xs = np.nonzero(image[..., 3])
        if len(xs):
            bounds = [min(bounds[0], int(xs.min())), min(bounds[1], int(ys.min())),
                      max(bounds[2], int(xs.max()) + 1), max(bounds[3], int(ys.max()) + 1)]
        metadata = store(image, CASE / 'pieces' / view, name, bounds=bounds)
        part.update(metadata, z_index=depths[name])
        parts.append(part)
        if any(m['name'] == name for m in old['joint_meshes']):
            field_bounds = next(m for m in old['joint_meshes'] if m['name'] == garment)['bbox']
            meshes.append(skin_layer(part, garment, field_bounds, layout['joints'], depths[name],
                part.get('hidden_material', False), recipe=anatomy['meshes'][garment]))
    # Reassigned skirt/neck pixels can no longer hide continuation in their
    # old main draw layer. Put that material below all visible paint, sharing
    # the original garment's weight field and rigid presentation anchor.
    for garment, fill in hidden.items():
        mask = (fill[..., 3] > 0) & ~allocated[garment] & (paint[..., 3] > 0)
        if not mask.any(): continue
        image = np.zeros_like(paint); image[mask] = fill[mask]
        name = 'mq7b_continuation_' + garment
        original = next(p for p in old['parts'] if p['name'] == garment)
        crop = None
        if garment in anatomy['meshes']:
            ys,xs = np.nonzero(mask)
            field = next(m for m in old['joint_meshes'] if m['name'] == garment)['bbox']
            crop = [int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
            crop[0] -= (crop[0]-field[0]) % 2
            crop[1] -= (crop[1]-field[1]) % 2
            crop[2] += (field[0]-crop[2]) % 2
            crop[3] += (field[1]-crop[3]) % 2
        part = dict(store(image, CASE / 'pieces' / view, name, bounds=crop),
            bone=original['bone'], z_index=min(depths.values()) - 1,
            hidden_material=True, logical_part=garment, joint_extension=True)
        if garment in anatomy['meshes']:
            bounds = next(m for m in old['joint_meshes'] if m['name'] == garment)['bbox']
            meshes.append(skin_layer(part, garment, bounds, layout['joints'], part['z_index'],
                                     True, recipe=anatomy['meshes'][garment]))
        else:
            part['presentation_anchor'] = original.get('presentation_anchor', original['offset'])
        parts.append(part)
    layout.update(parts=parts, joint_meshes=meshes)
    for mesh in meshes:
        garment = mesh['garment']
        bounds = next(p['bbox'] for p in parts if p['name'] == garment)
        mesh['weight_bounds'] = bounds
        from tools.humanoid_cutout.mesh import weights_for
        mesh['weights'] = weights_for(mesh['vertices'], bounds, layout['joints'], anatomy['meshes'][garment])
    distinct_depths(layout)
    # Donor coordinates are re-derived for final skin paint, at unchanged
    # gait-only transparent target coordinates.
    recipe_path = RECIPE / 'gait_continuations.json'
    recipes = read_json(recipe_path if recipe_path.exists() else BASELINE / 'gait_continuations.json')[view]
    for name, recipe in recipes.items():
        part = next(p for p in parts if p['name'] == name)
        recipe.update(nearest_donors(CASE, layout, part, [(x,y) for x,y,_,_ in recipe['texels']]))
    layout['gait_continuations'] = recipes
    proof_masks(layout, presentation, visible, hidden, rules(CASE, view), anatomy)
    write_json(CASE / f'layouts/{view}.json', layout)
    composed = Image.new('RGBA', (255,255))
    for part in sorted(parts, key=lambda p: p['z_index']):
        composed.alpha_composite(Image.fromarray(source_pixels(CASE, part)))
    mismatch = int(np.any(np.asarray(composed) != presentation, axis=-1).sum())
    report = deepcopy(read_json(BASELINE / 'build.json')['views'][view])
    report.update(front_rest_mismatch_pixels=mismatch, rest_mismatch_pixels=mismatch, tucks=reports,
                  raw_rest_mismatch_pixels=raw_mismatch, residue_correction_count=sum(map(len, corrections.values())),
                  source_job=str(job.relative_to(PROJECT)), source_sha256=digest(job / 'processed.png'))
    return layout, report


def main():
    layouts, reports = {}, {}
    for view in ('front', 'rear'):
        layouts[view], reports[view] = build_view(view)
        print(f'RR24 {view.upper()} MQ7B REST: {"PASS" if reports[view]["rest_mismatch_pixels"] == 0 else "FAIL"} ({reports[view]["rest_mismatch_pixels"]} px mismatch)')
    invalid = [view + ': ' + error for view,layout in layouts.items() for error in gait_errors(CASE,layout)]
    if invalid:
        raise ValueError('Rebuild rr11_gait_coverage.py after source-domain changes: ' + str(invalid))
    inputs = read_json(CASE / 'inputs.json')
    for view in layouts: inputs[view + '_job'] = f'spec/art_identity/jobs/arc_thrall/mq7b_{view}'
    write_json(CASE / 'inputs.json', inputs)
    write_json(CASE / 'gait_continuations.json', {v: l['gait_continuations'] for v,l in layouts.items()})
    build = dict(reports['front'], views=reports, director_sha256=digest(CASE / 'director_motion.json'),
        production_promoted=True, native_proof='pending director mq7b captures')
    build['rr24_derivation'] = {'builder_sha256':digest(Path(__file__)),
        'ownership_sha256':digest(RECIPE/'ownership.json'),
        'gait_coverage_sha256':digest(RECIPE/'gait_continuations.json'),
        'raw_authoring':'rr24/raw: exact mq7b RGBA, before the director residue rule',
        'presentation':'rr11 pieces/source presentation: same-piece residue cleanup only'}
    write_json(CASE / 'proof/build.json', build)
    promote(PROJECT, CASE, ASSETS, layouts)
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    if any(r['rest_mismatch_pixels'] for r in reports.values()): return 1
    return 0


if __name__ == '__main__': raise SystemExit(main())
