"""Repair mq13 coverage/ownership using only e4b60147b's approved texels.

The immutable input makes this a repeatable repair, not a new painting builder.
No joints, motion tracks, timing or weight-field recipes are changed. The traces
follow the painted cloak/boot boundaries, rather than the maquette categories.
"""
from copy import deepcopy
from io import BytesIO
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw
from rr35_case import PROJECT, CASE, ASSETS
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, interior_donors
from maquette_motion.silhouette import dilate
from humanoid_cutout.mesh import grid, weights_for
from humanoid_cutout.anatomy import load
from rr35_features import violet

BASE = 'e4b60147b4b87ced5e4a5195df827c2214b4fdb8'
# Measured source-space paint boundaries. They select ownership, never draw RGB.
CLOTH_EDGE = [(119, 162), (128, 166), (134, 177), (134, 182), (123, 178), (117, 169)]
LONG_HEM = [(140, 157), (143, 172), (145, 188), (147, 201), (148, 205),
            (151, 208), (151, 215), (159, 217), (163, 206), (170, 161)]


def own_interior(image):
    seed = image.copy()
    seed[violet(seed) | dilate(image[..., 3] == 0, 1)] = 0
    return seed


def original(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + str(path.relative_to(PROJECT))], cwd=PROJECT)


def full_image(part, raw):
    result = np.zeros((255, 255, 4), dtype=np.uint8)
    image = np.asarray(Image.open(BytesIO(raw)).convert('RGBA'))
    x, y = part['offset']; h, w = image.shape[:2]
    result[y:y+h, x:x+w] = image
    return result


def polygon(points):
    mask = Image.new('1', (255, 255))
    ImageDraw.Draw(mask).polygon(points, fill=1)
    return np.asarray(mask)


def transfer(images, mask, target, paint):
    mask = mask & (paint[..., 3] > 0)
    for name, image in images.items():
        if name.startswith('hidden_'): continue
        image[mask] = paint[mask] if name == target else 0


def save_part(part, image):
    y, x = np.nonzero(image[..., 3])
    # Retain the named, now fully occluded pelvis draw node and its old bounds.
    box = [int(x.min()), int(y.min()), int(x.max())+1, int(y.max())+1] if len(x) else part['bbox']
    part.update(bbox=box, offset=box[:2])
    Image.fromarray(image).crop(box).save(CASE / part['file'])


def repair(view):
    layout = json.loads(original(CASE / f'layouts/{view}.json'))
    old_parts = {p['name']: deepcopy(p) for p in layout['parts']}
    images = {p['name']: full_image(p, original(CASE / p['file'])) for p in layout['parts']}
    paint = np.asarray(Image.open(CASE / layout['rest_source']).convert('RGBA'))
    yy, xx = np.indices(paint.shape[:2])
    if view == 'front':
        # D1: near boot fringe was assigned to the far foot. Its 445-texel
        # gait bridge then connected that travelling island across the floor.
        transfer(images, (images['foot_far'][..., 3] > 0) & (yy >= 210), 'foot_near', paint)
        # D4: the projected pelvis cut sliced the SAME cloth at source y151.
        # Restore that cloth to the rigid torso surface immediately above it.
        pelvis = images['pelvis'][..., 3] > 0
        transfer(images, pelvis & (xx >= 109), 'torso', paint)
        transfer(images, pelvis & (xx < 109), 'leg_far', paint)
        # D2/D5: categorical leg fringes contained the cloak's ragged edge.
        transfer(images, polygon(CLOTH_EDGE) | polygon(LONG_HEM), 'cape_near', paint)
    else:
        # D3: the same projected pelvis cut also split painted rear thigh
        # wraps across torso/pelvis/leg nodes. The leg owns the entire wrap.
        thigh = (images['pelvis'][..., 3] > 0) | ((images['torso'][..., 3] > 0) &
                (yy >= 155) & (xx >= 89) & (xx <= 111))
        thigh &= np.asarray(Image.open(CASE / layout['carapace_ownership']['file']))[..., 3] == 0
        transfer(images, thigh, 'leg_near', paint)
    # D2/D3: reject flat maquette fills and foreign cloth/feature donors. Every
    # covered leg texel now continues the same painted wrapped limb.
    definition = rules(CASE, view)
    changed_hidden = ['hidden_leg_near', 'hidden_leg_far', 'hidden_cape_near', 'hidden_cape_far']
    for name in changed_hidden:
        own = images[name.removeprefix('hidden_')]
        # Copy only own interior material, never the silhouette's outline ring.
        seed = own_interior(own)
        target = images[name][..., 3] > 0
        if name.startswith('hidden_leg_'):
            side = name.rsplit('_', 1)[1]
            solo = np.logical_or.reduce([np.asarray(Image.open(CASE / f'{view}_baseline/registered/{view}_solo_{segment}_{side}.png'))[..., 3] > 128
                                         for segment in ('thigh', 'shin')])
            # The old underfill kept thin cloak-edge fragments outside the
            # actual limb. Use its certified solo silhouette and the unchanged
            # three-pixel joint tuck, rather than bridging those fragments.
            target = (solo | dilate(own[..., 3] > 0, anatomy_tuck_depth())) & (paint[..., 3] > 0) & (own[..., 3] == 0)
            from humanoid_cutout.materials import connected_mask
            target = connected_mask(own[..., 3] > 0, target)
        images[name] = edge_texels(seed, target, definition)
    # No hidden surface may repeat a violet drip: those exact original pixels
    # belong exclusively to the visible cloth and move with its field.
    for name, image in images.items():
        if not name.startswith('hidden_'): continue
        foreign = violet(image)
        if foreign.any():
            seed = images[name.removeprefix('hidden_')].copy(); seed[violet(seed)] = 0
            replacement = edge_texels(seed, foreign, definition)
            image[foreign] = replacement[foreign]
    # Ownership changes the exact masks to which the existing tuck rule is
    # applied. Recompute them, rather than preserving stale pre-cut masks or
    # relaxing the gate. The now occluded pelvis retains its original tuck.
    from humanoid_cutout.tucks import required_tuck
    anatomy = load(CASE)
    visible = {p['name']: images[p['name']] for p in layout['parts'] if not p.get('hidden_material')}
    build = read_json(CASE / 'proof/build.json')
    reports = build['views'][view]['tucks']
    for row in reports:
        name = row['piece']
        if not visible[name][..., 3].any(): continue
        required = required_tuck(name, visible, layout['joints'], anatomy['tucks'], continuation=images['hidden_' + name][..., 3] > 0)
        missing = required & (images['hidden_' + name][..., 3] == 0)
        seed = own_interior(visible[name]) if name.startswith('leg_') else visible[name].copy()
        seed[violet(seed)] = 0
        fill = edge_texels(seed, missing, definition)
        images['hidden_' + name][missing] = fill[missing]
        Image.fromarray(required.astype('uint8') * 255).save(CASE / row['required_mask'])
        row.update(required_pixels=int(required.sum()), missing_pixels=0)
    if view == 'front': build['tucks'] = deepcopy(reports)
    write_json(CASE / 'proof/build.json', build)
    # Original seam bridges are invalid after the ownership repair. Preserve
    # only unaffected recipes; regenerate geometry coverage separately.
    for table in [layout.get('gait_continuations', {})] + list(layout.get('clip_continuations', {}).values()):
        if view == 'front': table.pop('foot_far', None)
    for part in layout['parts']: save_part(part, images[part['name']])
    from humanoid_cutout.gait_continuations import nearest_donors
    for table in [layout.get('gait_continuations', {})] + list(layout.get('clip_continuations', {}).values()):
        for name, recipe in list(table.items()):
            part = next(p for p in layout['parts'] if p['name'] == name)
            delta = np.asarray(old_parts[name]['offset']) - part['offset']
            targets = {(int(x + delta[0]), int(y + delta[1])) for x, y, _, _ in recipe['texels']
                       if not images[name][y + old_parts[name]['offset'][1], x + old_parts[name]['offset'][0], 3]}
            table[name] = nearest_donors(CASE, layout, part, targets)
    anatomy = load(CASE)
    for mesh in layout['joint_meshes']:
        part = next(p for p in layout['parts'] if p['name'] == mesh['name'])
        garment = mesh['garment']
        visible = next(p for p in layout['parts'] if p['name'] == garment)
        mesh.update({k: deepcopy(part[k]) for k in ('file', 'offset', 'bbox')})
        mesh['weight_bounds'] = visible['bbox']
        mesh['vertices'], mesh['uvs'], mesh['triangles'] = grid(mesh['bbox'])
        mesh['weights'] = weights_for(mesh['vertices'], visible['bbox'], layout['joints'], anatomy['meshes'][garment])
    # Rebuild proof masks/tucks using the new ownership. Tuck depth is unchanged.
    from rr35_build import proof_masks
    visible = {p['name']: images[p['name']] for p in layout['parts'] if not p.get('hidden_material')}
    hidden = {name: images['hidden_' + name] for name in visible}
    proof_masks(layout, paint, visible, hidden, definition, anatomy)
    write_json(CASE / f'layouts/{view}.json', layout)
    return layout


def anatomy_tuck_depth():
    return load(CASE)['tucks']['base_px']


def production(layout):
    """Treat changed partitions with the EXISTING density settings, scoped here.

    Registry/source adoption and native rest certification are director work in
    the density stage. Accepted 187ce0327 rests remain untouched until rebake.
    """
    from pixel_density import process
    entry = next(e for e in read_json(PROJECT / 'spec/assets/board_pixel_density/registry.json')['entries'] if e['id'] == 'gloam_stalker_cutout')
    view = layout['facing']; settings = entry['facings'][view]
    result = deepcopy(layout)
    for part in result['parts'] + result['joint_meshes']:
        source = CASE / part['file']; target = ASSETS / 'humanoid_v2' / view / source.name
        with Image.open(source) as image:
            treated = process(image, settings['mode'], settings['grid'], entry['frames'])
        treated.save(target)
        part['file'] = view + '/' + source.name
    for key in ('proof_layers', 'proof_joint_seams', 'proof_rest_holes', 'features'):
        result.pop(key, None)
    rest = ASSETS / f'humanoid_v2/{view}/rest.png'
    result.update(rest_source=view + '/rest.png', rest_source_sha256=digest(rest),
                  motion_data='res://assets/units/gloam_stalker_cutout/humanoid_v2/compiled_motion.json')
    write_json(ASSETS / f'humanoid_v2/{view}.json', result)
    for part in result['parts'] + result['joint_meshes']: part['file'] = 'humanoid_v2/' + part['file']
    result['rest_source'] = 'humanoid_v2/' + result['rest_source']
    write_json(ASSETS / f'{view}.json', result)


def preservation_receipt():
    """Reconcile ONLY the two accepted director-rebaked rest records.

    Other authorized changes are explicit derived partitions, with both hashes;
    the pre-change baseline is retained rather than replacing it with this run.
    """
    round0_path = CASE / 'proof/round0/samples.json'
    round0 = read_json(round0_path)
    revision = 'a7a894dbbd93572115de7d4673851241449acd43'
    receipt_path = CASE / 'proof/rr36_preservation.json'
    previous_rests = read_json(receipt_path)['rest_baseline_reconciliation'] if receipt_path.exists() else {}
    rests = {}
    for view in ('front', 'rear'):
        path = ASSETS / f'humanoid_v2/{view}/rest.png'
        relative = str(path.relative_to(PROJECT))
        accepted = subprocess.check_output(['git', 'show', revision + ':' + relative], cwd=PROJECT)
        expected = hashlib.sha256(accepted).hexdigest()
        if digest(path) != expected: raise ValueError('Accepted director rest changed before native rebake: ' + relative)
        key = 'production:' + relative
        old = json.loads(original(round0_path))['inputs'][key]
        rests[key] = {'before_sha256': old, 'accepted_sha256': expected, 'revision': revision}
        # An unchanged rest retains its original recorded provenance. The
        # rr-36 rebake changes only front; rear's 187ce0327 record is exact.
        previous = previous_rests.get(key, {})
        if previous.get('before_sha256') == old and previous.get('accepted_sha256') == expected:
            rests[key] = previous
        round0['inputs'][key] = expected
    write_json(round0_path, round0)
    changes = {}
    for key, expected in round0['inputs'].items():
        if not key.endswith('.png'): continue
        path = PROJECT / key[len('production:'):] if key.startswith('production:') else CASE / key
        if digest(path) != expected:
            relative = str(path.relative_to(PROJECT))
            allowed = (relative.startswith(str(CASE.relative_to(PROJECT)) + '/' + folder + '/')
                       for folder in ('pieces', 'checks', 'seams', 'tucks'))
            production_part = (path.parent in (ASSETS / 'humanoid_v2/front', ASSETS / 'humanoid_v2/rear')
                               and path.name != 'rest.png')
            if not any(allowed) and not production_part:
                raise ValueError('Protected/non-part source changed: ' + key)
            if hashlib.sha256(original(path)).hexdigest() != expected:
                raise ValueError('Pre-repair source did not match preservation baseline: ' + key)
            changes[key] = {'before_sha256': expected, 'after_sha256': digest(path)}
    write_json(receipt_path, {'repair_base': BASE, 'rest_baseline_reconciliation': rests,
        'authorized_derived_partitions': changes, 'protected_motion_sha256': digest(CASE / 'director_motion.json'),
        'scope': 'own derived coverage/ownership only; painting, maquette, motion and other rigs untouched'})


def pending_integration():
    path = ASSETS / 'integration.json'
    data = read_json(path)
    data.update(ready=False, native_proof='rr36: pending fresh director density/rest/native/production/idle/review')
    data['density'].update(native_rest_pending=['front', 'rear'], paint='rr36 own partitions treated with existing settings; director adoption/registration pending')
    data['files'] = {name: digest(ASSETS / name) for name in data['files'] if (ASSETS / name).is_file()}
    write_json(path, data)


if __name__ == '__main__':
    if '--stage-density' in sys.argv:
        # Director-only preparation: give the existing adoption/processing
        # pipeline raw derived partitions, never already treated output.
        import shutil
        for view in ('front', 'rear'):
            for part in read_json(CASE / f'layouts/{view}.json')['parts']:
                source = CASE / part['file']
                shutil.copyfile(source, ASSETS / 'humanoid_v2' / view / source.name)
        print('RR36 DENSITY SOURCE STAGING: PASS (own raw partitions; native rebake still required)')
        raise SystemExit(0)
    for view in ('front', 'rear'):
        production(repair(view))
    preservation_receipt()
    pending_integration()
    print('RR36 OWNERSHIP/CONTINUATION REPAIR: PASS (protected paint, joints and motion untouched)')
