"""Read-only mq-04 delivery checks and rr-07 source registration.

No Blender invocation, image generation, source repainting or guessed geometry.
The native recipe compiler is pure Python; committed joints remain authoritative.
"""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
sys.path.insert(0, str(PROJECT))
from art_identity_gate import pixel_digest, replay_raw_steps
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_cutout import Registration, projected, registration
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.view_delivery import spec_for_view

CREATURES = ('hoarfrost_seer', 'arc_thrall')
VIEWS = ('front', 'rear')
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-07/motion_tracks.json'
# Diagnostic dimensions only. Production dimensions come from the approved jobs.
PROOF_DEFAULTS = {'input_cell_px': 255, 'input_columns': 6,
                  'input_label_height_px': 30, 'outline_zoom': 8,
                  'outline_crop_margin_px': 3,
                  'full_godot_timeout_seconds': 900,
                  'registration_joint_tolerance_px': 0.02}


def delivery_for(creature):
    return PROJECT / 'spec/art_identity/maquettes' / creature / 'delivery'


def job_for(creature, view):
    return PROJECT / read_json(DIRECTOR)[creature]['art'][view]


def audit(creature):
    """Fail before case creation if any committed rig input is absent or stale."""
    folder = delivery_for(creature)
    measurements = folder.parent / 'measurements.json'
    recipe = read_json(measurements)
    manifest = read_json(folder / 'capture_manifest.json')
    required = ['joints_px.json'] + [f'{view}_{kind}.png' for view in VIEWS
        for kind in ('parts', 'clay', *('solo_' + part for part in recipe['labels']))]
    errors = []
    hashes = {}
    for name in required:
        path = folder / name
        if not path.is_file():
            display = path.relative_to(PROJECT) if path.is_relative_to(PROJECT) else path
            errors.append('Missing committed rig input: ' + str(display))
            continue
        hashes[name] = digest(path)
        expected = (manifest['joints_sha256'] if name == 'joints_px.json'
                    else manifest['images'].get(name, {}).get('sha256'))
        if hashes[name] != expected:
            errors.append('Committed capture hash differs: ' + name)
        if name.endswith('.png'):
            with Image.open(path) as image:
                if image.size != (1024, 1024):
                    errors.append('Committed capture size differs: ' + name)
                image.verify()
    if errors:
        raise CutoutError('\n'.join(errors))
    spec = compile_recipe(recipe)
    joints = read_json(folder / 'joints_px.json')
    joint_errors = {}
    for view in VIEWS:
        view_spec = spec_for_view(spec, folder, view)
        if set(joints[view]) != set(view_spec['joints']):
            raise CutoutError('Committed joint names differ: ' + view)
        joint_errors[view] = max(float(np.linalg.norm(np.subtract(projected(view_spec, p, view), joints[view][n])))
                                 for n, p in view_spec['joints'].items())
        if joint_errors[view] > PROOF_DEFAULTS['registration_joint_tolerance_px']:
            raise CutoutError('Compiled camera differs from committed joints: ' + view)
        job = job_for(creature, view)
        if pixel_digest(Image.open(job / 'processed.png')) != read_json(job / 'processed.json')['pixel_sha256']:
            raise CutoutError('Approved processed art digest differs: ' + view)
    return {'ok': True, 'creature': creature, 'files': hashes,
            'measurements_sha256': digest(measurements),
            'director_sha256': digest(DIRECTOR), 'joint_max_error_px': joint_errors,
            'missing': [], 'blender_invocations': 0}


def raw_source_path(creature, view):
    job = job_for(creature, view)
    record = read_json(job / 'processed.json')
    if record.get('raw_steps'):
        return None
    # Raw file names are retained in the approved kit. Find by the approved hash,
    # never by a visually similar image or a historical job.
    # A front raw is also sometimes retained as the paired rear kit's identity
    # reference. Only an exact approved file digest is eligible.
    for path in sorted(job.parent.rglob('*.png')):
        if digest(path) == record['raw_sha256']:
            return path
    raise CutoutError('Missing approved registration raw: ' + str(job))


def raw_image(creature, view):
    source = raw_source_path(creature, view)
    if source is None:
        return replay_raw_steps(job_for(creature, view) / 'kit.json')
    return Image.open(source).convert('RGBA')


def registration_audit(creature):
    """Readiness is separate from the complete committed-solo inventory."""
    rows = []
    for view in VIEWS:
        job = job_for(creature, view)
        record = read_json(job / 'processed.json')
        row = {'view': view, 'job': str(job.relative_to(PROJECT)),
               'expected_raw_sha256': record.get('raw_sha256'),
               'expected_raw_pixel_sha256': record.get('raw_pixel_sha256')}
        try:
            source = raw_source_path(creature, view)
            if source is None:
                if pixel_digest(raw_image(creature, view)) != record['raw_pixel_sha256']:
                    raise CutoutError('Approved raw-step replay pixels differ')
                row.update(ok=True, kind='approved_raw_steps', source='kit.json')
            else:
                row.update(ok=True, kind='approved_file', source=str(source.relative_to(PROJECT)))
        except (CutoutError, ValueError, OSError) as error:
            row.update(ok=False, error=str(error),
                       placeholder='TODO_DESIGN_source_' + creature + '_' + view + '_raw')
        rows.append(row)
    return {'ok': all(row['ok'] for row in rows), 'views': rows}


def registered_transform(raw_path, record):
    """Same crop/trim transform as rr-04, with pixel-bound raw-step replay."""
    actual = pixel_digest(Image.open(raw_path))
    if record.get('raw_steps') and actual != record['raw_pixel_sha256']:
        raise CutoutError('Replayed approved raw pixels differ')
    if not record.get('raw_steps') and digest(raw_path) != record['raw_sha256']:
        raise CutoutError('Approved raw source file differs')
    adapted = dict(record, raw_sha256=digest(raw_path))
    result = registration(raw_path, adapted)
    ratio = result.trace['raw_size'][0] / 1024
    return Registration([s * ratio for s in result.scale], result.offset,
                        dict(result.trace, render_size=1024, render_to_raw_scale=ratio))


def label_palette(labels):
    # mq-04 render.py uses emission with Standard/sRGB, unlike rr-04's AgX.
    result = {}
    for name, linear in labels.items():
        rgb = np.asarray(linear)
        encoded = np.where(rgb <= .0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - .055)
        result[name] = np.rint(encoded * 255).astype(int).tolist()
    return result


if __name__ == '__main__':
    complete = True
    for creature in CREATURES:
        result = audit(creature)
        print('RR07 DELIVERY: PASS (%s; %d committed files)' % (creature, len(result['files'])))
        readiness = registration_audit(creature)
        for row in readiness['views']:
            print('RR07 REGISTRATION SOURCE: %s (%s/%s%s)' % (
                'PASS' if row['ok'] else 'BLOCKED', creature, row['view'],
                '; ' + row['placeholder'] if not row['ok'] else ''))
        complete = complete and readiness['ok']
    sys.exit(0 if complete else 2)
