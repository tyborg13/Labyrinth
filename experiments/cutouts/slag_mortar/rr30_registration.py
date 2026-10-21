"""Register a newly supplied view without touching a frozen view's ownership.

The rr-07 categorical/nearest partition and rr-05 same-surface texel donors
operate on the approved painting and maquette solos. No mirrored source or
historical rear paint participates in this derivation.
"""
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

from cutout_pipeline.cases import digest, read_json, write_json
from art_identity_gate import pixel_digest
from maquette_cutout import decode_labels, nearest_labels, hidden_region, depth_order, projected
from maquette_motion.bleed import edge_texels
from maquette_motion.silhouette import components
from maquette_motion.continuity import adjacent_counts
from maquette_motion.material_palette import rules
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.view_delivery import spec_for_view


def prepare(project, case, inputs, view, pieces, registration, palette_for, depths_for, recipe_for, bind_layout):
    """Return a replayable rr-07-shaped baseline for this approved new view."""
    delivery = project / inputs[view + '_delivery']
    job = project / inputs[view + '_job']
    base = case / (view + '_baseline')
    source = base / 'source' / view
    source.mkdir(parents=True, exist_ok=True)
    record = read_json(job / 'processed.json')
    if pixel_digest(Image.open(job/'processed.png')) != record['pixel_sha256']:
        raise ValueError('Changed approved painting: '+view)
    manifest=read_json(delivery/'capture_manifest.json')
    raw = next((p for p in sorted(job.rglob('*.png')) if digest(p) == record['raw_sha256']), None)
    if raw is None:
        raise ValueError('TODO_DESIGN_' + view + '_registration_raw')
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(job / name, source / name)
    shutil.copyfile(raw, source / 'raw.png')
    base_spec = read_json(delivery / 'source_spec.json')
    spec = spec_for_view(base_spec, delivery, view)
    transform = registration(raw, record)
    registered = base / 'registered'
    registered.mkdir(exist_ok=True)
    bound = {}
    for name in ['joints_px.json', view + '_parts.png'] + [view + '_solo_' + n + '.png' for labels in pieces.values() for n in labels]:
        bound[name] = digest(delivery / name)
        expected=manifest['joints_sha256'] if name=='joints_px.json' else manifest['images'][name]['sha256']
        if bound[name]!=expected:
            raise ValueError('Changed certified maquette input: '+name)
        if name.endswith('.png'):
            transform.image(Image.open(delivery / name).convert('RGBA')).save(registered / name)
    names = list(spec['labels'])
    palette = palette_for(spec['labels'])
    native_depth = depths_for(spec, view)
    depths = depth_order(native_depth)
    labels = decode_labels(Image.open(registered / (view + '_parts.png')), palette, names, native_depth)
    rgba = np.asarray(Image.open(registered / (view + '_parts.png')).convert('RGBA')).astype(int)
    solos = {}
    for index, name in enumerate(names):
        solo = np.asarray(Image.open(registered / (view + '_solo_' + name + '.png')).convert('RGBA'))[..., 3] > 128
        solos[name] = solo
        # Same genuine-interior seed rule as rr-07 native_operations.decode.
        labels[(labels == index) & (~solo | (np.abs(rgba[..., :3] - palette[name]).max(-1) > 1))] = -1
    paint = np.asarray(Image.open(source / 'processed.png').convert('RGBA'))
    owners, reassigned = nearest_labels(labels, paint[..., 3] > 0, names, native_depth)
    # rr-07 neighbour ownership cleanup for unsupported tiny categorical
    # fringes. A boot-outline pixel must not ride a distant held item simply
    # because the nearest unoccluded maquette label was the shaft.
    transfers=[]
    for index,name in enumerate(names):
        labels,groups=components(owners==index)
        for label,size in groups[1:]:
            fragment=labels==label
            if size>8 or (fragment & solos[name]).any(): continue
            contacts=adjacent_counts(fragment,owners,len(names))
            contacts[index]=0
            if not contacts.max(): continue
            destination=int(contacts.argmax())
            owners[fragment]=destination
            transfers.append({'from':name,'to':names[destination],'pixels':size})
    recipe = recipe_for(spec['id'], spec)
    joints, mapping = bind_layout(spec, view, transform, read_json(delivery / 'joints_px.json')[view], recipe)
    definition = rules(base, view)
    parts, fills = [], {}
    for index, name in enumerate(names):
        image = np.zeros_like(paint)
        selected = owners == index
        image[selected] = paint[selected]
        ys, xs = np.nonzero(selected)
        if not len(xs):
            # Visible ownership stays empty even when a separately approved
            # donor supplies this fully covered surface.
            placeholder='TODO_DESIGN_' + view + '_' + name + '_hidden_paint'
            donor = inputs.get('occluded_donors', {}).get(view, {}).get(name)
            fused = next(group for group in pieces.values() if name in group)
            fused_visible = inputs.get('fused_occlusion', False) and any(
                (owners == names.index(other)).any() for other in fused if other != name)
            if donor is None and not fused_visible and placeholder not in inputs.get('design_placeholders',{}):
                raise ValueError(placeholder)
            ys, xs = np.nonzero(solos[name])
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        relative = f'pieces/{view}/{name}.png'
        target = base / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(image).crop(bounds).save(target)
        parts.append({'name': name, 'logical_part': name, 'bone': mapping[name], 'file': relative,
                      'offset': bounds[:2], 'bbox': bounds, 'z_index': depths.index(name)})
        hidden, _ = hidden_region(solos[name], owners, index)
        fills[name] = edge_texels(image, hidden, definition) if selected.any() else np.zeros_like(image)
    layout = {'facing': view, 'canvas_size': [255, 255], 'joints': joints, 'parts': parts}
    write_json(base / f'layouts/{view}.json', layout)
    write_json(registered / (view + '_registration.json'), {'scale': transform.scale, 'offset': transform.offset, 'trace': transform.trace})
    write_json(base / 'source/spec_native.json', spec)
    write_json(base / 'derivation.json', {'painting_sha256': digest(source / 'processed.png'), 'delivery': bound,
        'policy': 'rr07 genuine categorical seeds / nearest ownership; rr05 non-outline same-surface edge texels',
        'nearest_assignment': reassigned, 'connected_neighbour_transfers': transfers})
    return base, layout, fills, bound
