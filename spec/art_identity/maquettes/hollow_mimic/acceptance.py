"""Bind batch-C fit, pose and mutation evidence to the sealed native delivery."""
import json

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.delivery_validation import passing, validate_delivery


BOUND_FILES = ('fit_report.json', 'fit_overlay.png', 'provenance.json',
               'recipe_proof.json', 'exact_native_replay.json', 'capture_manifest.json',
               'capture_packing.json', 'native_render_manifest.json',
               'validation/native_validation.json', 'validation/regeneration/regeneration.json',
               'validation/regeneration/clean_input_sha256.json')


def binding(folder):
    spec = compile_recipe(json.loads((folder / 'measurements.json').read_text()))
    delivery = folder / 'delivery'
    native = validate_delivery(spec, delivery)
    fit = json.loads((delivery / 'fit_report.json').read_text())
    mutation = json.loads((delivery / 'validation/native_validation.json').read_text())
    regeneration = json.loads((delivery / 'validation/regeneration/regeneration.json').read_text())
    for name, report in (('fit', fit), ('mutation', mutation), ('regeneration', regeneration)):
        passing(report, name)
        if report.get('passed') is not True:
            raise ValueError('Missing passing batch-C evidence: ' + name)
    if fit['spec_hash'] != digest(spec) or regeneration['compiled_spec_hash'] != digest(spec):
        raise ValueError('Stale batch-C acceptance inputs')
    if (fit['inputs']['recipe_sha256'] != sha(folder / 'measurements.json') or
            fit['inputs']['capture_manifest_sha256'] != sha(delivery / 'capture_manifest.json')):
        raise ValueError('Fit evidence belongs to different delivery inputs')
    if regeneration['cache_reused'] or not regeneration['comparison_required']:
        raise ValueError('Batch-C regeneration requires a fresh verified build')
    for view in ('front', 'rear'):
        for kind in ('clay', 'parts'):
            proof = regeneration['views'][view][kind]
            if (proof['sha256'] != proof['expected_sha256'] or
                    proof['delivery_file_sha256'] != sha(delivery / (view + '_' + kind + '.png'))):
                raise ValueError('Stale batch-C regeneration image: ' + view + '_' + kind)
    files = BOUND_FILES
    if spec['id'] == 'slag_mortar':
        files += ('validation/head_occlusion.json',)
        occlusion = json.loads((delivery / 'validation/head_occlusion.json').read_text())
        passing(occlusion, 'head occlusion')
        if (occlusion.get('passed') is not True or occlusion['spec_hash'] != digest(spec) or
                occlusion['cold_mesh_hash'] != native['cold_mesh_hash'] or
                occlusion.get('checks') != dict(front_face=True, rear_skull=True, rear_harness=True)):
            raise ValueError('Stale or failed native mortar/head occlusion')
    return {'schema': 1, 'spec_hash': digest(spec), 'recipe_sha256': sha(folder / 'measurements.json'),
            'cold_mesh_hash': native['cold_mesh_hash'],
            'report_sha256': {name: sha(delivery / name) for name in files}}


def seal(folder):
    write(folder / 'delivery/acceptance_binding.json', binding(folder))


def validate(folder):
    path = folder / 'delivery/acceptance_binding.json'
    if not path.is_file() or json.loads(path.read_text()) != binding(folder):
        raise ValueError('Missing or stale batch-C acceptance hash binding')
