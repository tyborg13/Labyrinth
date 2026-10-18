"""A frozen front can retain its cold proof while a rear uses another body.

No native proof is relabelled with another spec hash. The root certificate's
geometry is explicitly front-only; the rear has an independently sealed cold,
cache and exact-native certificate, sharing PNG storage with the delivery.
"""
import json
import math
from copy import deepcopy
from pathlib import Path
import shutil
import struct

from .capture_manifest import sha256
from .compile_recipe import compile_recipe
from .contract import digest


def local(root, name):
    path = Path(name)
    if path.is_absolute() or '..' in path.parts or not path.parts:
        raise ValueError('Per-view source must stay inside its figure')
    result = Path(root) / path
    if not result.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError('Per-view source escaped its figure')
    return result


def load(path):
    return json.loads(Path(path).read_text())


def source_spec(folder, source):
    recipe = local(Path(folder).parent, source['recipe'])
    if sha256(recipe) != source['recipe_sha256']:
        raise ValueError('Stale per-view recipe')
    spec = compile_recipe(load(recipe))
    if digest(spec) != source['spec_hash']:
        raise ValueError('Per-view recipe differs from native proof')
    return spec


def spec_for_view(base, folder, view):
    """Projection input for readers of a delivery with independently posed views.

    Compile the native view's actual recipe and apply its recorded camera pan.
    Never infer pose or camera coordinates from the joints being validated.
    """
    folder = Path(folder)
    path = folder / 'view_sources.json'
    if not path.is_file():
        spec = deepcopy(base)
        if view == 'rear' and spec.get('rear_capture'):
            frame = load(folder / 'capture_frame.json')[view]
            scale = struct.unpack('f', struct.pack('f', spec['ortho_scale']))[0]
            if (frame.get('passed') is not True or frame.get('camera_rotation_unchanged') is not True or
                    frame.get('ortho_scale') != scale or
                    frame.get('required_margin_px') != spec['rear_capture']['edge_margin_px']):
                raise ValueError('Invalid native pan-only framing for per-view projection')
            if 'view_transforms' in spec:
                spec['view_transforms'][view]['target'] = frame['target']
            else:
                spec['target'] = frame['target']
        return spec
    sources = load(path)
    if sources['base_spec_hash'] != digest(base):
        raise ValueError('Stale base specification for per-view projection')
    source = sources['overrides'].get(view)
    if source is None:
        return deepcopy(base)
    spec = source_spec(folder, source)
    frame = load(local(folder, source['certificate']) / 'capture_frame.json')[view]
    if 'view_transforms' in spec:
        spec['view_transforms'][view]['target'] = frame['target']
    else:
        spec['target'] = frame['target']
    return spec


def validate_override(spec, folder, manifest, reports, proof):
    from .delivery_validation import load as report, passing, validate_delivery
    folder = Path(folder)
    sources = load(folder / 'view_sources.json')
    if sources.get('schema') != 1 or sources.get('base_views') != ['front'] or set(sources.get('overrides', {})) != {'rear'}:
        raise ValueError('Unsupported per-view delivery scope')
    if sources.get('base_spec_hash') != digest(spec):
        raise ValueError('Stale frozen-front specification')
    for value in (reports['build_report.json'], reports['capture_checks.json'], proof):
        if value.get('geometry_scope') != ['front']:
            raise ValueError('Base native proof must explicitly cover the frozen front')
    frozen = sources['frozen_front']
    actual = {p.name: sha256(p) for p in folder.glob('front_*')}
    if frozen['files'] != actual or load(folder / 'joints_px.json')['front'] != frozen['joints']:
        raise ValueError('Frozen front bytes or joints changed')
    source = sources['overrides']['rear']
    rear = source_spec(folder, source)
    if rear['labels'] != spec['labels'] or list(rear['labels']) != list(spec['labels']) or set(rear['joints']) != set(spec['joints']):
        raise ValueError('Per-view labels or joint identities differ')
    certificate = local(folder, source['certificate'])
    if certificate == folder:
        raise ValueError('Rear requires its own native certificate')
    validate_delivery(rear, certificate, views=('rear',), image_folder=folder)
    captured = load(certificate / 'capture_manifest.json')
    expected = {name: value for name, value in manifest['images'].items() if name.startswith('rear_')}
    if captured['images'] != expected or any(not name.startswith('rear_') for name in captured['images']):
        raise ValueError('Rear certificate differs from staged rear images')
    if load(certificate / 'joints_px.json') != {'rear': load(folder / 'joints_px.json')['rear']}:
        raise ValueError('Rear certificate differs from staged joints')
    if load(certificate / 'capture_frame.json') != load(folder / 'capture_frame.json'):
        raise ValueError('Rear certificate differs from staged camera framing')
    if rear.get('rear_body'):
        from .floor_contact import contact_guard, expected_contact_names
        floor = load(certificate / 'build_report.json')['geometry_details']['floor_contact']
        checked = contact_guard({name: row['height_m'] for name, row in floor['points'].items()},
                                rear['joints']['ankle_near'][2], rear['rear_body']['exceptions'],
                                required_contacts=expected_contact_names(rear, 'rear'))
        if not checked['passed'] or floor.get('hem_on_or_above_floor') is not True or checked['points']['hem_min']['above_floor_m'] < 0:
            raise ValueError('Rear floor contact guard failed')
    policy_path = local(folder.parent, sources['fit_policy'])
    policy = load(policy_path)
    fit_path = local(folder, sources['fit_report'])
    fit = report(fit_path)
    passing(fit, 'rear fit')
    if (policy.get('figure') != spec['id'] or policy.get('view') != 'rear' or not policy.get('authority') or
            fit.get('registration_method') != policy.get('method') or fit.get('spec_hash') != digest(rear) or
            fit.get('iou_min') != policy.get('iou_min') or fit.get('passed') is not True or
            not fit.get('checks') or any(value is not True for value in fit['checks'].values()) or
            not math.isfinite(fit.get('iou', float('nan'))) or fit['iou'] < policy['iou_min']):
        raise ValueError('Missing, stale or failed per-view rear fit gate')
    if (policy['method'] == 'fixed_original_mq04' and
            (fit.get('fixed_original_iou') != fit['iou'] or not math.isfinite(fit.get('dynamic_iou', float('nan'))) or
             fit.get('registration_reason') != policy.get('reason'))):
        raise ValueError('Fixed registration must retain both IoUs and the owner decision')
    coverage = fit.get('per_part_coverage', {})
    if set(coverage) != set(spec['labels']) or any(not row.get('solo_pixels') or
            not (row.get('pure_owner_pixels') or row.get('recorded_occlusion')) for row in coverage.values()):
        raise ValueError('Rear lacks genuine part pixels or documented occlusion')
    from .view_fit import validate_pixels
    validate_pixels(rear, load(local(folder.parent, source['recipe'])), folder, certificate,
                    policy, fit, load(certificate / 'capture_frame.json'))
    return {'manifest_sha256': sha256(folder / 'view_sources.json'),
            'rear_recipe_sha256': source['recipe_sha256'],
            'rear_cold_certificate_sha256': sha256(certificate / 'recipe_proof.json'),
            'fit_policy_sha256': sha256(policy_path), 'fit_report_sha256': sha256(fit_path)}


def copy_sources(source, destination):
    """Preserve view inputs when copying an already curated delivery."""
    source, destination = Path(source), Path(destination)
    sources = load(source / 'view_sources.json')
    shutil.copyfile(source / 'view_sources.json', destination / 'view_sources.json')
    for entry in sources['overrides'].values():
        shutil.copytree(local(source, entry['certificate']), local(destination, entry['certificate']), dirs_exist_ok=True)
    paths = [sources['fit_policy'], *(entry['recipe'] for entry in sources['overrides'].values())]
    for name in paths:
        target = local(destination.parent, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(local(source.parent, name), target)
    for name in [sources['fit_report'], *sources['frozen_front']['files']]:
        if not name.endswith('.png'):
            shutil.copyfile(local(source, name), local(destination, name))


def refresh_override(folder):
    """Reseal a copied rear if optional lossless PNG packing changed its bytes."""
    from .delivery_validation import seal_delivery
    folder = Path(folder)
    sources = load(folder / 'view_sources.json')
    source = sources['overrides']['rear']
    certificate = local(folder, source['certificate'])
    manifest = load(certificate / 'capture_manifest.json')
    manifest['images'] = {name: value for name, value in load(folder / 'capture_manifest.json')['images'].items()
                          if name.startswith('rear_')}
    (certificate / 'capture_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    seal_delivery(source_spec(folder, source), certificate, views=('rear',), image_folder=folder)
