"""Build own-edge gait continuations from sampled seam and component gaps.

CPU raster is a construction aid. Native renderer acceptance remains required.
Only transparent texels in existing draw surfaces are populated in a declared
clip; original textures, skin weights, rest and idle remain untouched.
"""
from collections import Counter
import argparse
import numpy as np
from PIL import Image, ImageDraw
from rr37_coverage import SHAFT_BOUNDARY
from rr37_case import CASE, ASSETS
from rr37_frames import state
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.anatomy import load, owner_ids
from humanoid_cutout.cpu_pose import sprite_transform
from rr37_raster import CpuPose
from humanoid_cutout.gait_continuations import nearest_donors
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import holes, dilate, components

CLIPS = read_json(CASE / 'compiled_motion.json')['clips']
MAX_CONSTRUCTION_PASSES = 16  # Same convergence guard as gait-01.
RASTER_COVERAGE_MARGIN_PX = 1  # Cover both sides of the native pixel square.


def defects(model, pose):
    layers, maps, owners, pockets = state(model, pose)
    masks = []
    for hole in holes(owners > 0):
        y, x = np.nonzero(hole)
        box = [int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1]
        if any(p['bbox'] == box for p in pockets): masks.append(hole)
    labels, groups = components(owners > 0, 8)
    if groups:
        main = labels == groups[0][0]
        for label, _ in groups[1:]:
            component = labels == label
            release = CLIPS[pose['clip']].get('release_at', {}).get('spear', 2)
            if pose['phase'] >= release:
                item = np.logical_or.reduce([image[...,3]>0 for part,image,_ in layers if part['logical_part']=='spear'])
                if np.all(item[component]): continue  # Released rigid item; never paint a bridge back to the body.
            # Bridge the shortest separation to the main silhouette. A
            # continuation covers the piece's edge; no detached paint is cut.
            a = np.argwhere(component)
            boundary = main & dilate(~main, 1)
            b = np.argwhere(boundary)
            distance = np.sum((a[:, None] - b[None]) ** 2, axis=2)
            i, j = np.unravel_index(distance.argmin(), distance.shape)
            start, end = a[i], b[j]
            count = int(np.max(np.abs(end - start))) + 1
            line = np.rint(np.linspace(start, end, count)).astype(int)
            gap = component.copy()
            gap[line[:, 0], line[:, 1]] = True
            masks.append(gap)
    return masks, owners, maps


def extend(model, pose, mask, owners, maps):
    ids = owner_ids(load(CASE)['ownership'])
    reverse = {v: k for k, v in ids.items()}
    vocabulary = load(CASE)['ownership']['segments']
    logical = {owner: garment for garment, record in vocabulary.items() for owner in record['owners']}
    boundary = owners[dilate(mask, 1) & (owners > 0)]
    counts = Counter(logical.get(reverse[int(n)], reverse[int(n)]) for n in boundary)
    target = dilate(mask, RASTER_COVERAGE_MARGIN_PX)
    options = []
    for part in model.layout['parts']:
        if part['logical_part'] not in counts: continue
        source = model.image(part['file'])
        if part['name'] in maps:
            mapping = maps[part['name']]
            keep = target[mapping.pixels[:, 1], mapping.pixels[:, 0]]
            xy, uv = mapping.pixels[keep], mapping.texels[keep]
        else:
            y, x = np.nonzero(target)
            xy = np.column_stack((x, y))
            inverse = np.linalg.inv(sprite_transform(model.layout, pose, part))
            local = (xy + .5 - PROOF_DEFAULTS['source_offset']) @ inverse[:2, :2].T + inverse[:2, 2]
            uv = np.floor(local).astype(int)
        u, v = uv.T
        valid = (u >= 0) & (v >= 0) & (u < source.shape[1]) & (v < source.shape[0])
        if model.layout['facing']=='front' and part['logical_part']=='hand_far':
            from rr43_spear import front_hand_support
            support=front_hand_support()
            sx,sy=u+part['offset'][0],v+part['offset'][1]
            inside=valid & (sx>=0) & (sx<255) & (sy>=0) & (sy<255)
            valid[inside] &= support[sy[inside],sx[inside]]
        if model.layout['facing']=='front' and part['logical_part']=='spear':
            from rr43_spear import front_shaft_support
            support=front_shaft_support()
            sx,sy=u+part['offset'][0],v+part['offset'][1]
            inside=valid & (sx>=0) & (sx<255) & (sy>=0) & (sy<255)
            valid[inside] &= support[sy[inside],sx[inside]]
        if model.layout['facing']=='rear':
            sx,sy=u+part['offset'][0],v+part['offset'][1]
            if part['logical_part'].startswith('cape_'):
                path=f'uncovered/outer_rear_{part["logical_part"]}.png'
                outline=model.image(path)[...,0]>0
                inside=valid & (sy>=80) & (sy<=180)
                valid[inside] &= outline[sy[inside],sx[inside]]
            elif part['logical_part']=='spear':
                from rr37_surfaces import rear_shaft_core
                valid &= rear_shaft_core(sx,sy)
        xy, uv = xy[valid], uv[valid]
        missing = source[uv[:, 1], uv[:, 0], 3] == 0
        covered = int(mask[xy[missing, 1], xy[missing, 0]].sum())
        if covered:
            options.append((covered, counts[part['logical_part']], bool(part.get('hidden_material')), part, uv[missing]))
    if not options: raise ValueError(f'No existing surface covers {pose["view"]}/{pose["frame"]} gap')
    _, _, _, part, uv = max(options, key=lambda r: r[:3])
    targets = {tuple(p) for p in uv}
    table = (model.layout.setdefault('gait_continuations', {}) if pose['clip'] == 'move' else
             model.layout.setdefault('clip_continuations', {}).setdefault(pose['clip'], {}))
    old = table.get(part['name'], {}).get('texels', [])
    targets.update((x, y) for x, y, _, _ in old)
    table[part['name']] = nearest_donors(CASE, model.layout, part, targets)


def build(samples, actions=False):
    recipes = {}
    for view in ('front', 'rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        field = 'clip_continuations' if actions else 'gait_continuations'
        layout.pop(field, None)
        part = next(p for p in layout['parts'] if p['name']=='hidden_spear')
        mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon(SHAFT_BOUNDARY[view],fill=1)
        x0,y0,x1,y1=part['bbox']
        source=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))
        visible=next(p for p in layout['parts'] if p['name']=='spear')
        from maquette_motion.features import source_pixels
        target=np.asarray(mask)&(source_pixels(CASE,visible)[...,3]==0)
        if view=='rear':
            from rr37_surfaces import rear_shaft_core
            yy,xx=np.indices(target.shape);target &= rear_shaft_core(xx,yy)
        y,x=np.nonzero(target[y0:y1,x0:x1]&(source[...,3]==0))
        recipe=nearest_donors(CASE,layout,part,set(zip(x.tolist(),y.tolist())))
        if actions:
            layout[field]={clip:{'hidden_spear':recipe} for clip in CLIPS if clip not in ('move','idle')}
        else: layout[field]={'hidden_spear':recipe}
        model = CpuPose(CASE, layout)
        clips = [c for c in read_json(CASE / 'compiled_motion.json')['clips'] if c not in ('move', 'idle')] if actions else ['move']
        before = []
        for clip in clips:
            poses = [p for p in samples['samples'] if p['view'] == view and p['clip'] == clip and p['kind'] == 'presented']
            for index in range(MAX_CONSTRUCTION_PASSES):
                count = 0
                for pose in poses:
                    masks, owners, maps = defects(model, pose)
                    if index == 0 and masks: before.append({'clip': clip, 'frame': pose['frame'], 'gaps': len(masks)})
                    for mask in masks:
                        extend(model, pose, mask, owners, maps)
                        count += 1
                print(f'RR37 {view.upper()} {clip.upper()} COVERAGE: pass {index + 1}, {count} gaps', flush=True)
                if not count: break
            else: raise ValueError('Joint coverage did not converge')
        recipes[view] = layout.get(field, {})
        for part in layout['parts']: part.pop('proof_ownership', None)
        write_json(CASE / f'layouts/{view}.json', layout)
        for folder in (ASSETS / 'humanoid_v2',):
            path = folder / (view + '.json')
            production = read_json(path)
            production[field] = recipes[view]
            write_json(path, production)
        write_json(CASE / f'proof/logs/{field}/{view}.json', {'native_pixels': False, 'before': before})
    write_json(CASE / (field + '.json'), recipes)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--actions', action='store_true')
    build(read_json(CASE / 'proof/logs/samples.json'), parser.parse_args().actions)
