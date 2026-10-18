"""Build only rr-07 cases with the unchanged rr-04/rr-05 operations."""
import argparse
from contextlib import contextmanager
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace
from unittest.mock import patch

from rr07_inputs import *
from rr07_prepare import case_for, stage
from rr07_geometry import recipe_for, bind_layout, native_depths, projection_for
import maquette_cutout as builder
from cutout_pipeline.cases import baseline
from cutout_pipeline.validation import validate
from maquette_motion import compiler, continuity, silhouette, joint_seams, seam_pose, hidden_material
from maquette_motion.feature_builder import ownership_adapter, extract_nodes, record_partition

RUNTIME_PATHS = [
    'scripts/static_enemy_facing.gd',
    'assets/units/hoarfrost_seer_cutout/precision.gd',
    'assets/units/hoarfrost_seer_cutout/actions.gd',
    'assets/units/hoarfrost_seer_cutout/renderer.gd',
    'assets/units/hoarfrost_seer_cutout/rig.gd',
    'assets/units/arc_thrall_cutout/renderer.gd',
    'assets/units/arc_thrall_cutout/rig.gd',
    'tests/rr07/production_capture.gd', 'tests/rr07/capture_scene.gd', 'tests/rr07/motion_samples.gd',
] + ['experiments/cutouts/hoarfrost_seer/rr07_' + name + '.py'
     for name in ('inputs', 'prepare', 'geometry', 'build', 'contract', 'gates')]
REJECT_SAMPLE_STRIDE = 6  # Diagnostic acceleration; acceptance always checks every frame.


def connected_hidden_seed(case, view, part, original):
    """rr-05: retain fills joined to this bone's visible material only.

    Immutable request previews and filled seeds remain on disk. This derives a
    support mask; it cannot remove or reassign an approved visible paint pixel.
    Separate visible sections (the occluded staff) each seed their own region.
    """
    from maquette_motion.features import source_pixels
    layout = read_json(case / f'layouts/{view}.json')
    footprint = np.zeros(original.shape[:2], dtype=bool)
    for owner in layout['parts']:
        if owner['bone'] == part['bone'] and not any(owner.get(k) for k in
                ('hidden_material', 'seam_underlay', 'silhouette_backing')):
            footprint |= source_pixels(case, owner)[..., 3] > 0
    labels, groups = silhouette.components((original[..., 3] > 0) | footprint)
    retained = [label for label, _ in groups if (footprint & (labels == label)).any()]
    if not retained and groups:
        retained = [groups[0][0]]
    result = original.copy()
    result[~np.isin(labels, retained)] = 0
    records_path = case / 'proof/hidden_seed_connectivity.json'
    records = read_json(records_path) if records_path.exists() else {}
    records[view + '/' + part['name']] = {
        'excluded_hidden_only_pixels': int(((original[..., 3] > 0) & (result[..., 3] == 0)).sum()),
        'policy': 'rr-05: no isolated hidden-only seed; keep every visible ownership component'}
    write_json(records_path, records)
    return result


@contextmanager
def native_operations(case):
    """Adapters affect this process/case only; historical rigs remain untouched."""
    original_regions = joint_seams.rest_regions
    original_decode = builder.decode_labels
    original_parent = joint_seams.parent_part

    def decode(image, palette, names, depths):
        labels = original_decode(image, palette, names, depths)
        # Native emission maps have categorical flat interiors and AA fringes.
        # mq-04's own coverage policy requires a genuine flat colour inside its
        # solo. Dark AA/stitch pixels cannot seed a remote material's Voronoi.
        view = state['view']
        rgba = np.asarray(image.convert('RGBA')).astype(int)
        records = {}
        for index, name in enumerate(names):
            solo = np.asarray(Image.open(case / f'registered/{view}_solo_{name}.png').convert('RGBA'))[..., 3] > 128
            flat = np.abs(rgba[..., :3] - palette[name]).max(-1) <= 1
            invalid = (labels == index) & (~solo | ~flat)
            records[name] = {'rejected_fringe_seeds': int(invalid.sum()),
                             'genuine_seeds': int(((labels == index) & solo & flat).sum())}
            labels[invalid] = -1
        write_json(case / f'proof/{view}_categorical_seeds.json', records)
        return labels

    state = {'view': 'front'}

    def regions(root, layout):
        # A complete rigid crystal has only its protected feature node. Such a
        # feature neither donates nor receives generated seam material. Ordinary
        # features still expand their material owner's boundary exactly as rr-05.
        material = {p['name'] for p in joint_seams.material_parts(layout)}
        filtered = dict(layout, parts=[p for p in layout['parts'] if not p.get('feature')
                        or p.get('logical_part', p['bone']) in material])
        return original_regions(root, filtered)

    def body(layout):
        # Director calls torso the primary body; planted feet are root siblings.
        # This chooses only the report/native-reference surface, never a pose.
        return next(p for p in layout['parts'] if p['name'] == 'torso')

    def parent(layout, first, second, decisions):
        if first['bone'] == second['bone']:
            return min((first, second), key=lambda p: (p['z_index'], layout['parts'].index(p)))
        return original_parent(layout, first, second, decisions)

    with patch.object(builder, 'registration', registered_transform), \
         patch.object(builder, 'bind_layout', bind_layout), \
         patch.object(builder, 'camera_depths', native_depths), \
         patch.object(builder, 'decode_labels', decode), \
         patch.object(joint_seams, 'rest_regions', regions), \
         patch.object(joint_seams, 'parent_part', parent), \
         patch.object(seam_pose, 'body_part', body):
        yield state


def sample(case, kind='pixel_samples'):
    target = case / ('proof/' + ('continuity_samples' if kind == 'pixel_samples' else 'motion_samples') + '.json')
    script = 'tests/maquette_cutout/pixel_samples.gd' if kind == 'pixel_samples' else 'tests/rr07/motion_samples.gd'
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-07', '--stream', '--',
               'godot', '--headless', '--path', '.', '--script', script,
               '--', '--case', str(case), '--output', str(target)]
    process = subprocess.run(command, cwd=PROJECT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    target.with_suffix('.log').write_text(process.stdout)
    if process.returncode:
        raise CutoutError('Headless sampler failed: ' + process.stdout[-5000:])
    print(process.stdout.strip().splitlines()[-1], flush=True)
    return read_json(target)


def split_components(case, view, hidden_only=False):
    """Store disconnected visible islands as separate connected physical crops.

    Ownership, bone, depth and RGBA are unchanged. All crops on a bone share the
    original named owner anchor. Motion silhouette gates still see every pixel.
    Protected features remain exactly one node and are never split here.
    """
    from maquette_motion.features import source_pixels
    path = case / f'layouts/{view}.json'
    layout = read_json(path)
    parts, records = [], []
    for part in layout['parts']:
        if part.get('feature') or bool(part.get('hidden_material')) != hidden_only or part.get('seam_underlay'):
            parts.append(part)
            continue
        image = source_pixels(case, part)
        labels, groups = silhouette.components(image[..., 3] > 0)
        if len(groups) <= 1:
            parts.append(part)
            continue
        for index, (label, count) in enumerate(groups):
            node = dict(part)
            if index:
                node['name'] = part['name'] + '_component_%02d' % (index + 1)
                folder = 'hidden' if hidden_only else 'segmented'
                node['file'] = f'{folder}/{view}/{node["name"]}.png'
            selected = np.zeros_like(image)
            selected[labels == label] = image[labels == label]
            continuity.store(case, node, selected)
            parts.append(node)
            records.append({'source': part['name'], 'node': node['name'], 'pixels': count,
                            'bone': node['bone'], 'z_index': node['z_index']})
    layout['parts'] = parts
    write_json(path, layout)
    kind = 'hidden' if hidden_only else 'visible'
    write_json(case / f'proof/{view}_{kind}_component_crops.json', {'parts': records,
               'policy': 'Lossless connected storage crops; no paint reassignment or deletion'})


def connected_ownership(case, view):
    """rr-05 neighbour cleanup, preserving director-bound occluded garments.

    Native clothing and rigid props may appear on both sides of an occluding
    limb. Their physical crops remain on the specified logical owner's bone.
    Ordinary body fringe islands retain rr-05's stable connected-neighbour rule.
    No source pixel changes its source coordinate or RGBA.
    """
    from maquette_motion.features import source_pixels
    path = case / f'layouts/{view}.json'
    layout = read_json(path)
    parts = joint_seams.material_parts(layout)
    plane = np.full((255, 255), -1, dtype=np.int32)
    pending, records = [], []
    bound_materials = {'collar', 'loincloth', 'club', 'staff_shaft', 'staff_crystal', 'skirt_near', 'skirt_far'}
    for index, part in enumerate(parts):
        labels, groups = silhouette.components(source_pixels(case, part)[..., 3] > 0)
        if part.get('logical_part') in bound_materials:
            # Only native-supported sections identify genuine occlusion. An
            # inferred nearest-label fringe outside the entire solo is handled
            # by the ordinary rr-05 connected-neighbour cleanup.
            solo = np.asarray(Image.open(case / f'registered/{view}_solo_{part["logical_part"]}.png').convert('RGBA'))[..., 3] > 128
            plane[labels == groups[0][0]] = index
            for label, count in groups[1:]:
                mask = labels == label
                if (mask & solo).any():
                    plane[mask] = index
                    records.append({'from': part['name'], 'to': part['name'], 'pixels': count,
                        'reason': 'Native-supported occluded material: connected crop on unchanged director bone'})
                else:
                    pending.append((index, mask))
        else:
            plane[labels == groups[0][0]] = index
            pending.extend((index, labels == label) for label, _ in groups[1:])
    while pending:
        choices = []
        for order, (original, mask) in enumerate(pending):
            contacts = continuity.adjacent_counts(mask, plane, len(parts))
            contacts[original] = 0
            if contacts.max():
                choices.append((int(contacts.max()), -order, int(contacts.argmax())))
        if not choices:
            for original, mask in pending:
                plane[mask] = original
                records.append({'from': parts[original]['name'], 'to': parts[original]['name'],
                    'pixels': int(mask.sum()), 'reason': 'Protected-boundary pocket; connected storage crop'})
            break
        _, negative_order, destination = max(choices)
        original, mask = pending.pop(-negative_order)
        plane[mask] = destination
        records.append({'from': parts[original]['name'], 'to': parts[destination]['name'], 'pixels': int(mask.sum())})
    paint = np.asarray(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))
    for index, part in enumerate(parts):
        image = np.zeros_like(paint)
        image[plane == index] = paint[plane == index]
        continuity.store(case, part, image)
    write_json(path, layout)
    split_components(case, view)
    return records


def build(creature):
    case = case_for(creature)
    stage(creature)
    spec = read_json(case / 'source/spec_native.json')
    recipe = read_json(case / 'rig_recipe.json')
    write_json(case / 'source/spec.json', spec)
    write_json(case / 'recipes/rig.json', recipe)
    # Rebuild only generated outputs. Protected inputs/case decisions stay put.
    for name in ('segmented', 'hidden', 'hidden_requests', 'hidden_fills', 'layouts', 'seams'):
        shutil.rmtree(case / name, ignore_errors=True)
    for name in ('seams.json', 'support_derivation.json'):
        (case / name).unlink(missing_ok=True)
    config = {'schema_version': 1, 'character_id': creature, 'source_size': [255, 255],
              'runtime_paths': RUNTIME_PATHS,
              'canvas_size': [512, 512], 'source_offset': [128, 128], 'default_facing': 'front',
              'layouts': {v: f'layouts/{v}.json' for v in VIEWS}, 'sources': [],
              'motion': 'motion.gd', 'clips': recipe['clips'], 'rigid_bones': [], 'contact_feet': [],
              'design_placeholders': {}, 'source_baseline': {'kind': 'maquette_registered_paint',
              'art_status': 'hidden_material_incomplete', 'production_integration': False}}
    (case / 'motion.gd').write_text('extends "res://scripts/maquette_cutout_runtime/motion.gd"\n')
    with patch.object(compiler, 'projection', lambda s, p, m, v: projection_for(case, s, p, m, v)):
        compiled = compiler.compile_creature(DIRECTOR, creature, spec, recipe)
    write_json(case / 'compiled_motion.json', compiled)
    write_json(case / 'cutout.json', config)
    requests, views = [], {}
    with native_operations(case) as native, ownership_adapter(builder, case) as state:
        for view in VIEWS:
            state['view'] = view
            native['view'] = view
            result = builder.build_view(case, spec, view, label_palette(spec['labels']), recipe, False)
            extract_nodes(case, view, recipe['parts'])
            path = case / f'layouts/{view}.json'
            layout = read_json(path)
            layout['native_angle_ties'] = True
            # Whole-part features still supply their bone's shared snap anchor.
            for part in layout['parts']:
                if part.get('feature') and not any(p['name'] == part['bone'] for p in layout['parts']):
                    part['name'] = part['bone']
            layout['motion_data'] = 'res://' + str(case.relative_to(PROJECT) / 'compiled_motion.json')
            write_json(path, layout)
            record_partition(case, view, layout)
            requests.extend(result.pop('requests'))
            views[view] = result
        write_json(case / 'hidden_requests/index.json', {'exposure_basis': 'sample after director motion binding', 'requests': requests})
        # Preserve exact sources in the generic baseline, including rr-07 code.
        config['sources'] = sorted({str(p.relative_to(case)) for folder in ('source', 'registered', 'recipes')
            for p in (case / folder).rglob('*') if p.is_file() and p.suffix != '.import'} |
            {'director_motion.json', 'compiled_motion.json', 'features.json', 'rig_recipe.json'} |
            {d['mask'] for f in read_json(case / 'features.json')['features'] for d in f['views'].values()})
        write_json(case / 'cutout.json', config)
        print('RR07 BASE: ' + creature + ' ' + str(builder.rest_identity(case)), flush=True)
        filled = builder.fill_hidden(SimpleNamespace(case=case, cross_view_fallback=False))
        write_json(case / 'proof/hidden_fill_result.json', filled)
        if not filled['ok'] or filled['pending_design']:
            raise CutoutError('Incomplete hidden material: ' + str(filled['pending_design']))
    write_json(case / 'build_report.json', {'ok': True, 'views': views, 'rest_identity': builder.rest_identity(case),
                                         'validation': validate(case)})
    baseline(case)
    return case


def derive(case):
    with native_operations(case):
        transfers = {view: connected_ownership(case, view) for view in VIEWS}
        write_json(case / 'support_derivation.json', {
            'authority': 'rr-05 non-outline same-part seam donors',
            'policy': 'Source paint stays exact; seam bands use existing interior parent texels; no feature donors',
            'tool_sha256': digest(Path(__file__))})
        attempts = []
        reject_probe_pose = None
        from maquette_motion import support_seeds
        original_seed = support_seeds.approved
        for margin in range(256):
            with patch.object(support_seeds, 'approved', lambda c, v, p:
                    connected_hidden_seed(c, v, p, original_seed(c, v, p))):
                supports = continuity.underlays(case, margin)
            samples = sample(case)
            seams = joint_seams.install(case, samples)
            if seams['TODO_DESIGN']:
                raise CutoutError(str(seams['TODO_DESIGN']))
            samples = sample(case)
            # A failed subset proves a failed full trial. Only a full passing
            # trial ends the search, so this preserves the exact minimum margin.
            subset = dict(samples, samples=[r for r in samples['samples'] if
                (r['view'], r['clip'], r['frame']) == reject_probe_pose] if reject_probe_pose else
                [r for r in samples['samples'] if r['frame'] % REJECT_SAMPLE_STRIDE == 0])
            poses = silhouette.pose_report(case, subset)
            if reject_probe_pose and not any(r['islands'] for r in poses['poses']):
                poses = silhouette.pose_report(case, dict(samples, samples=[
                    r for r in samples['samples'] if r['frame'] % REJECT_SAMPLE_STRIDE == 0]))
            if not any(r['islands'] for r in poses['poses']):
                poses = silhouette.pose_report(case, samples)
            if any(r['islands'] for r in poses['poses']):
                worst = max(poses['poses'], key=lambda r: r['detached_pixels'])
                reject_probe_pose = tuple(worst[k] for k in ('view', 'clip', 'frame'))
            row = {'margin': margin, 'errors': len(poses['errors']),
                   'max_detached_pixels': max(r['detached_pixels'] for r in poses['poses'])}
            attempts.append(row)
            write_json(case / 'proof/continuity_search.json', {'attempts': attempts,
                       'last_poses': poses, 'search_sample_stride': REJECT_SAMPLE_STRIDE,
                       'reject_probe_pose': reject_probe_pose,
                       'acceptance': 'A subset may reject a trial; only all 60 Hz poses may accept it.'})
            print('RR07 CONTINUITY: ' + str(row), flush=True)
            if not any(r['islands'] for r in poses['poses']):
                break
        else:
            raise CutoutError('TODO_DESIGN_silhouette_support: source envelope cannot connect all poses')
        seams = joint_seams.install(case, samples)
        if seams['TODO_DESIGN']:
            raise CutoutError(str(seams['TODO_DESIGN']))
        for view in VIEWS:
            split_components(case, view, hidden_only=True)
        samples = sample(case)
        poses = silhouette.pose_report(case, samples)
        seam_report = seam_pose.report(case, samples)
        material = hidden_material.report(case, samples)
        for view in VIEWS:
            record_partition(case, view, read_json(case / f'layouts/{view}.json'))
        continuity.seal(case, transfers, supports, margin)
        proof = read_json(case / 'proof/continuity.json')
        proof.update(ok=poses['ok'] and seam_report['ok'] and material['ok'], attempts=attempts,
                     poses=seam_pose.summary(poses), seams=seam_pose.summary(seam_report),
                     exposed_hidden=seam_pose.summary(material), TODO_DESIGN=[])
        write_json(case / 'proof/continuity.json', proof)
        write_json(case / 'proof/feature_derivation.json', {
            'tool_sha256': digest(Path(__file__)), 'features_sha256': digest(case / 'features.json')})
        print('RR07 DERIVE: ' + str({'ok': proof['ok'], 'errors': (poses['errors'] + material['errors'])[:12]}), flush=True)
    baseline(case)
    return proof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('build', 'derive', 'samples'))
    parser.add_argument('--creature', choices=CREATURES, required=True)
    args = parser.parse_args()
    case = build(args.creature) if args.command == 'build' else case_for(args.creature)
    if args.command == 'derive':
        derive(case)
    elif args.command == 'samples':
        sample(case, 'samples')


if __name__ == '__main__':
    main()
