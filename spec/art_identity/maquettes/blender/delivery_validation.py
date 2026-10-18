"""Fail-closed native delivery reports, sealed into the current cold proof.

The seal records report bytes, capture bytes and cold geometry identity. Sealing
is an explicit staging operation, never a side effect of verification.
"""
import json
from pathlib import Path

from .capture_manifest import read_manifest, require_image, sha256
from .contract import digest
from .ownership import require_solos

REPORTS = ('build_report.json', 'capture_checks.json', 'facing_report.json',
           'ownership_validation.json', 'solo_coverage.json')
GEOMETRY_CHECKS = ('labels_cover_every_face', 'view_piece_ownership',
    'polygon_material_ownership', 'body_weight_ownership', 'cloth_collision_margin',
    'collar_front_no_wider_than_back', 'plate_corners_preserved', 'armour_conforms_to_body')
PROOF_CHECKS = ('fresh_and_replay_raw_hashes', 'joint_endpoints', 'native_geometry')
BUILDS = ('cold', 'replay', 'independent_cold')


def load(path):
    if not path.is_file():
        raise ValueError('Required delivery report is missing: ' + path.name)
    return json.loads(path.read_text())


def passing(value, path):
    """Do not trust a summary boolean when a nested check reports failure."""
    if isinstance(value, dict):
        for key, item in value.items():
            if (key == 'passed' or key.endswith('_passed')) and item is not True:
                raise ValueError('Failed delivery check: ' + path + '.' + key)
            passing(item, path + '.' + key)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            passing(item, path + '.' + str(index))


def checks(report, required, name):
    values = report.get('checks', {})
    if not values or any(values.get(key) is not True for key in required) or any(v is not True for v in values.values()):
        raise ValueError('Missing or failed checks: ' + name)


def proof_path(folder, name):
    direct = folder / name
    return direct if direct.exists() else folder / 'determinism' / name


def validate_delivery(spec, folder, require_binding=True, views=('front', 'rear'), image_folder=None):
    folder = Path(folder)
    if not views or len(set(views)) != len(views) or not set(views) <= {'front', 'rear'}:
        raise ValueError('Delivery requires explicit supported view scope')
    current = digest(spec)
    manifest = read_manifest(folder, current, ('full',), image_folder)
    for view in views:
        for kind in ('clay', 'parts'):
            require_image(manifest, view + '_' + kind + '.png')
    report_names = tuple(name for name in REPORTS if name != 'facing_report.json' or 'front' in views)
    reports = {name: load(folder / name) for name in report_names}
    for name, report in reports.items():
        passing(report, name)
        if name != 'solo_coverage.json' and report.get('passed') is not True:
            raise ValueError('Missing or failed passed field: ' + name)
        if 'spec_hash' in report and report['spec_hash'] != current:
            raise ValueError('Stale delivery report: ' + name)
    build = reports['build_report.json']
    capture = reports['capture_checks.json']
    if (build.get('geometry_scope', list(views)) != list(views) and
            not (folder / 'view_sources.json').is_file()):
        raise ValueError('Scoped geometry requires its per-view source certificate')
    if build.get('spec_hash') != current or capture.get('spec_hash') != current:
        raise ValueError('Missing current build/capture spec hash')
    required = GEOMETRY_CHECKS + ('board_facing_axis', 'required_solo_coverage', 'capture_geometry_unchanged')
    checks(build, required + (('rendered_torso_asymmetry',) if 'front' in views else ()), 'build')
    if any(capture.get('geometry_checks', {}).get(key) is not True for key in GEOMETRY_CHECKS) or any(
            v is not True for v in capture.get('geometry_checks', {}).values()):
        raise ValueError('Missing or failed capture geometry checks')
    if capture.get('geometry_unchanged') is not True:
        raise ValueError('Capture changed geometry')
    if 'front' in views:
        facing = reports['facing_report.json']
        if any(facing.get(key) is not True for key in ('passed', 'torso_asymmetry_passed', 'frontal_axis_rejected')):
            raise ValueError('Missing or failed facing check')
        if capture.get('facing') != facing:
            raise ValueError('Capture facing differs from facing report')
    cloth = build.get('cloth', {})
    expected = {p['id'] for p in spec['pieces'] if p['type'] == 'cloth'}
    expected |= {a + '__' + b for a, b in spec.get('cloth_obstacles', [])}
    if set(cloth) != expected:
        raise ValueError('Missing or stale collision report')
    for name, report in cloth.items():
        if report.get('passed') is not True or report.get('samples_below_margin') != 0 or report.get('intersecting_face_pairs') != 0:
            raise ValueError('Missing or failed collision check: ' + name)
    ownership = reports['ownership_validation.json']
    if ownership.get('empty_required_solos') != {view: [] for view in views}:
        raise ValueError('Missing or failed ownership coverage')
    for view in views:
        require_solos(spec['labels'], reports['solo_coverage.json'].get(view, {}))
    proof = load(proof_path(folder, 'recipe_proof.json'))
    exact = load(proof_path(folder, 'exact_native_replay.json'))
    for name, value in (('cold proof', proof), ('exact replay', exact)):
        passing(value, name)
        if value.get('passed') is not True or value.get('spec_hash') != current:
            raise ValueError('Missing or stale ' + name)
    checks(proof, PROOF_CHECKS, 'cold proof')
    hashes = proof.get('combined_mesh_hashes', {})
    cold = hashes.get('cold')
    if not cold or any(hashes.get(name) != cold for name in BUILDS) or proof.get('raw_hashes_identical') is not True:
        raise ValueError('Cold/replay geometry differs')
    if build.get('combined_mesh_hash') != cold or digest(build.get('mesh_hashes', {})) != cold:
        raise ValueError('Build differs from cold proof')
    for field in ('mesh_hashes', 'joint_matrix_hashes'):
        values = exact.get(field, {})
        if not values.get('cold') or any(values.get(name) != values['cold'] for name in BUILDS):
            raise ValueError('Exact native replay differs: ' + field)
    if exact.get('mesh_count') != len(build['mesh_hashes']) or proof.get('mesh_count') != len(build['mesh_hashes']):
        raise ValueError('Native proof mesh count differs')
    bound = {name: sha256(folder / name) for name in report_names + ('capture_manifest.json',)}
    if tuple(views) != ('front', 'rear'):
        bound.update({name: sha256(folder / name) for name in ('capture_frame.json', 'cloak_side.json', 'native_capture_manifest.json')
                      if (folder / name).is_file()})
    binding = {'spec_hash': current, 'cold_mesh_hash': cold, 'report_sha256': bound,
               'exact_native_replay_sha256': sha256(proof_path(folder, 'exact_native_replay.json'))}
    if tuple(views) != ('front', 'rear'):
        binding['views'] = list(views)
    if (folder / 'view_sources.json').exists():
        from .view_delivery import validate_override
        binding['view_sources'] = validate_override(spec, folder, manifest, reports, proof)
    if require_binding and proof.get('delivery_binding') != binding:
        raise ValueError('Missing or stale cold-proof report hash binding')
    return binding


def seal_delivery(spec, folder, views=('front', 'rear'), image_folder=None):
    """Attach validated capture report hashes to an existing matching cold proof."""
    folder = Path(folder)
    binding = validate_delivery(spec, folder, require_binding=False, views=views, image_folder=image_folder)
    path = proof_path(folder, 'recipe_proof.json')
    proof = load(path)
    proof['delivery_binding'] = binding
    path.write_text(json.dumps(proof, indent=2, allow_nan=False) + '\n')
    validate_delivery(spec, folder, views=views, image_folder=image_folder)
