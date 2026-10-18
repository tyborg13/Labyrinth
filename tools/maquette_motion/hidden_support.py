"""Feedback 11: immutable painted fills plus one interior-colour joint margin."""
from pathlib import Path
import shutil
import tempfile
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest, CutoutError
from maquette_motion import continuity, silhouette, material_palette, support_seeds
from maquette_motion.features import source_pixels


def legacy_base(seed, footprint, rest, maximum_margin):
    """Reproduce the old cumulative search only to identify accepted bleed."""
    current = seed[..., 3] > 0
    for margin in range(maximum_margin + 1):
        domain = footprint if footprint.any() else current
        candidate = (current | silhouette.dilate(domain, margin)) & rest
        labels, groups = silhouette.components(candidate)
        current = labels == max(groups, key=lambda g: int(((labels == g[0]) & domain).sum()))[0]
    return current


def rebuild(case):
    proof = read_json(case / 'proof/continuity.json')
    margin = proof['joint_overlap_margin_px']
    records = []
    manifest_path = case / 'support_derivation.json'
    for view in ('front', 'rear'):
        path = case / f'layouts/{view}.json'
        layout = read_json(path)
        definition = material_palette.rules(case, view)
        original = {p['name']: source_pixels(case, p) for p in layout['parts']}
        rest = np.asarray(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))[..., 3] > 0
        visible = [p for p in layout['parts'] if not p.get('hidden_material') and not p.get('seam_underlay')]
        protected = np.zeros_like(rest)
        for p in visible:
            if p.get('feature'):
                protected |= original[p['name']][..., 3] > 0
        for part in layout['parts']:
            if not part.get('hidden_material'):
                continue
            painted = support_seeds.approved(case, view, part)
            # Ownership cleanup already removed original orphan texels. Do not
            # resurrect those obsolete islands from the untouched source mask.
            painted[original[part['name']][..., 3] == 0] = 0
            seed = painted.copy()
            painted_mask = painted[..., 3] > 0
            owners = [p for p in visible if p['bone'] == part['bone'] and not p.get('feature')]
            footprint = np.zeros_like(rest)
            for owner in owners:
                own = original[owner['name']]
                mask = own[..., 3] > 0
                footprint |= mask
                seed[mask & ~painted_mask] = own[mask & ~painted_mask]
            seed_mask = seed[..., 3] > 0
            # Feedback 11 shrinks existing support; it does not introduce new
            # support beyond the accepted envelope or move a crop/pivot.
            target = silhouette.dilate(seed_mask, margin) & rest & (original[part['name']][..., 3] > 0)
            labels, groups = silhouette.components(target)
            connected = labels == max(groups, key=lambda g: int(((labels == g[0]) & seed_mask).sum()))[0]
            if np.any(painted_mask & ~connected):
                raise CutoutError(f'TODO_DESIGN_hidden_seed_connectivity_{view}_{part["name"]}: approved paint outside its joint-connected region')
            target = connected
            # Features neither supply nor receive generated paint. Original
            # approved fill may overlap them only underneath the feature node.
            generated = target & ~painted_mask & ~protected
            donors = seed.copy()
            donors[protected] = 0
            replicated = continuity.nearest_existing(donors, generated, definition) if generated.any() else np.zeros_like(seed)
            result = painted.copy()
            result[generated] = replicated[generated]
            labels, groups = silhouette.components(result[..., 3] > 0)
            connected = labels == groups[0][0]
            if np.any(painted_mask & ~connected):
                raise CutoutError(f'TODO_DESIGN_hidden_feature_connectivity_{view}_{part["name"]}: removing feature overlap splits approved paint')
            result[~connected] = 0
            continuity.store(case, part, result)
            records.append({'view': view, 'part': part['name'], 'bone': part['bone'],
                            'visible_owners': [p['name'] for p in owners],
                            'painted_pixels': int(painted_mask.sum()), 'support_pixels': int((result[..., 3] > 0).sum()),
                            'joint_margin_px': margin,
                            'original_painted_rgba_preserved': bool(np.array_equal(result[painted_mask], painted[painted_mask])),
                            'painted_fill_preview': next(r['preview'] for r in read_json(case / 'hidden_fills/index.json')['requests']
                                                        if r['view'] == view and r['part'] == part['logical_part'])})
        write_json(path, layout)
    write_json(manifest_path, {'authority': 'Director rr-05 feedback 11',
               'policy': 'Approved painted seed plus one joint margin; no cumulative trials or foreign hidden-only seeds; non-outline same-part/bone donors',
               'tool_sha256': digest(Path(__file__)), 'parts': records,
               'outline_rules': {v: material_palette.rules(case, v) for v in ('front', 'rear')}})
    return records


def derive(case, task_id):
    from maquette_motion import seam_builder, joint_seams
    with tempfile.TemporaryDirectory(dir=case.parent, prefix='rr05-hidden-') as temporary:
        work = Path(temporary) / 'case'
        shutil.copytree(case, work)
        rebuild(work)
        samples = seam_builder.sample(work, task_id)
        joint_seams.install(work, samples)
        from maquette_motion import socket_edit
        socket = socket_edit.apply(work, samples)
        index = read_json(work / 'hidden_fills/index.json')
        for record in index['requests']:
            for output in record.get('outputs', []):
                output['output_sha256'] = digest(work / output['output'])
        index['continuity']['feedback11'] = {'authority': 'Director feedback 11', 'derivation': 'support_derivation.json',
            'policy': 'Immutable approved painted fills; interior-only support donors; one joint margin'}
        index['continuity'].update(tool_sha256=digest(Path(continuity.__file__)),
            policy=read_json(work / 'support_derivation.json')['policy'],
            joint_seams_tool_sha256=digest(Path(joint_seams.__file__)))
        for view in ('front', 'rear'):
            index['protected_inputs'][f'layouts/{view}.json'] = digest(work / f'layouts/{view}.json')
        if socket:
            index['continuity']['feedback11']['director_authorized_derived_edits'] = [socket]
        write_json(work / 'hidden_fills/index.json', index)
        config = read_json(work / 'cutout.json')
        config['sources'] = sorted(set(config['sources']) | {'support_derivation.json'} | ({socket['mask']} if socket else set()))
        write_json(work / 'cutout.json', config)
        # Bind the final textures, layout, policy and configuration together.
        # Sealing afterwards must not invalidate the sampled render inputs.
        samples = seam_builder.sample(work, task_id)
        result = seam_builder.seal(work, samples)
        from maquette_motion.gates import input_bindings
        if samples['inputs'] != input_bindings(work):
            raise CutoutError('Hidden-support seal changed sampled inputs; no adoption performed')
        from cutout_pipeline.cases import baseline
        baseline(work)
        for folder in ('hidden', 'seams'):
            shutil.copytree(work / folder, case / folder, dirs_exist_ok=True)
        if (work / 'support').exists():
            shutil.copytree(work / 'support', case / 'support', dirs_exist_ok=True)
        for relative in ('support_derivation.json', 'seams.json', 'cutout.json', 'baseline.sha256.json',
                         'layouts/front.json', 'layouts/rear.json', 'proof/continuity.json',
                         'proof/continuity_samples.json', 'proof/feature_derivation.json', 'hidden_fills/index.json'):
            shutil.copyfile(work / relative, case / relative)
    return result
