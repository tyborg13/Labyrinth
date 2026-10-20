"""Portable input-snapshot and native-triangle replay acceptance regressions."""
from contextlib import ExitStack
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

from spec.art_identity.maquettes.blender.accessory_geometry.forms import pelvis_frame
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.hollow_mimic.owner_review import measurements, proof, workflow
from spec.art_identity.maquettes.hollow_mimic.owner_review.preservation import source_dependencies
from spec.art_identity.maquettes.raster import camera
from tests.test_mq11_accessories import FIXTURE, PROJECT, mortar_design

FRESHNESS_FIXTURE = {'run_id': 'mq11-freshness-fixture', 'figure': 'slag_mortar',
                     'before': {'source.py': 'before'}, 'after': {'source.py': 'after'},
                     'blend_bytes': b'synthetic frozen blend fixture', 'mesh_hash': 'synthetic mesh hash'}


def native_capture(capture):
    """Actual triangle measurement, synthetic native metadata; no Blender launch."""
    capture.mkdir(parents=True)
    spec = {'id': FRESHNESS_FIXTURE['figure'], **deepcopy(FIXTURE['attachment_camera']),
            'joints': deepcopy(FIXTURE['attachment_joints']), 'mq11': {'design': mortar_design()}}
    origin, forward, _, up, _ = pelvis_frame(spec)
    matrix, _, basis, _ = camera(spec, 'front')
    right = basis[0] @ matrix[:3, :3]
    width, length = FIXTURE['attachment_flap_size_m']
    meshes = {}
    for name, sign in (('leather_apron', 1), ('rear_leather_apron', -1)):
        anchor = origin + sign * forward * FIXTURE['belt']['forward_radius_m']
        meshes[name] = {'vertices': [(anchor + right * x - up * y).tolist()
                                    for x, y in ((-width / 2, 0), (width / 2, 0),
                                                 (width / 2, length), (-width / 2, length))],
                        'faces': [[0, 1, 2, 3]]}
    write(capture / 'build_report.json', {'passed': True, 'spec_hash': digest(spec),
                                         'combined_mesh_hash': FRESHNESS_FIXTURE['mesh_hash']})
    (capture / 'maquette.blend').write_bytes(FRESHNESS_FIXTURE['blend_bytes'])
    binding = {'spec_hash': digest(spec), 'cold_mesh_hash': FRESHNESS_FIXTURE['mesh_hash'],
               'build_report_sha256': sha(capture / 'build_report.json'),
               'blend_sha256': sha(capture / 'maquette.blend')}
    write(capture / 'mq11_meshes.json', dict(binding, meshes=meshes))
    report = measurements.measure(spec, meshes)
    assert report['passed'], 'Synthetic native fixture must pass before mutation'
    report.update(binding, mesh_export_sha256=sha(capture / 'mq11_meshes.json'))
    write(capture / 'mq11_shape.json', report)
    return spec


def verification_fixture(stack, output, spec, current):
    snapshot = FRESHNESS_FIXTURE['before']
    write(output / 'input_sha256.json', snapshot)
    write(output / 'acceptance.json', {'passed': True, 'spec_hash': digest(spec),
                                      'inputs_sha256': snapshot, 'files_sha256': {}})
    stack.enter_context(patch.object(workflow, 'FIGURES', (FRESHNESS_FIXTURE['figure'],)))
    stack.enter_context(patch.object(workflow, 'check'))
    stack.enter_context(patch.object(workflow, 'compile_candidate', return_value=spec))
    stack.enter_context(patch.object(workflow, 'output_folder', return_value=output))
    stack.enter_context(patch.object(workflow, 'inputs', return_value=current))
    stack.enter_context(patch.object(workflow, 'validate_delivery'))


class DependencyInputTests(unittest.TestCase):
    def test_complete_local_import_closure_includes_relative_conditional_and_package_modules(self):
        with tempfile.TemporaryDirectory(prefix='mq11-dependencies-', dir=PROJECT) as temporary:
            root = Path(temporary)
            sources = {'entry.py': 'from pkg import worker\n',
                       'pkg/__init__.py': 'raise RuntimeError("Must never import this package")\n',
                       'pkg/worker.py': 'if False:\n    from .deep import geometry\n__import__("pkg.late")\n',
                       'pkg/deep/__init__.py': '',
                       'pkg/deep/geometry.py': 'from .. import shared\n',
                       'pkg/shared.py': 'import json\n', 'pkg/late.py': 'import math\n'}
            for name, source in sources.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source)
            found = source_dependencies(root, [root / 'entry.py'])
            self.assertEqual({str(p.relative_to(root)) for p in found}, set(sources))

    def test_workflow_binds_raster_geometry_fit_and_rear_turn_dependencies(self):
        inputs = workflow.inputs()
        for path in ('spec/art_identity/maquettes/raster.py', 'spec/art_identity/maquettes/geometry.py',
                     'spec/art_identity/maquettes/fitting.py', 'spec/art_identity/maquettes/hollow_mimic/batch_proof.py',
                     'tests/test_maquette_rear_turn.py', 'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json'):
            with self.subTest(path=path):
                self.assertEqual(inputs[path], sha(PROJECT / path))


class AcceptanceFreshnessTests(unittest.TestCase):
    def test_prepare_snapshots_before_compiling_and_rejects_input_changes(self):
        with (patch.object(workflow, 'check'),
              patch.object(workflow, 'compile_candidate', return_value={'id': 'fixture'}),
              patch.object(workflow, 'inputs', side_effect=[FRESHNESS_FIXTURE['before'], FRESHNESS_FIXTURE['after']]),
              patch.object(workflow, 'write') as writer):
            with self.assertRaisesRegex(ValueError, 'inputs changed since preparation'):
                workflow.prepare(FRESHNESS_FIXTURE['run_id'])
            writer.assert_not_called()

    def test_build_cannot_refresh_a_changed_snapshot_at_acceptance(self):
        with tempfile.TemporaryDirectory(prefix='mq11-build-freshness-', dir=PROJECT) as temporary, ExitStack() as stack:
            state = deepcopy(FRESHNESS_FIXTURE['before'])
            output = Path(temporary) / FRESHNESS_FIXTURE['figure']
            stack.enter_context(patch.object(workflow, 'FIGURES', (FRESHNESS_FIXTURE['figure'],)))
            stack.enter_context(patch.object(workflow, 'check'))
            stack.enter_context(patch.object(workflow, 'inputs', side_effect=lambda: deepcopy(state)))
            stack.enter_context(patch.object(workflow, 'compile_candidate', return_value={'id': FRESHNESS_FIXTURE['figure']}))
            stack.enter_context(patch.object(workflow, 'output_folder', return_value=output))
            stack.enter_context(patch.object(workflow, 'inspect', return_value={'passed': True}))
            stack.enter_context(patch.object(workflow, 'sheet'))
            stack.enter_context(patch.object(workflow, 'seal_delivery'))
            stack.enter_context(patch.object(workflow, 'validate_delivery'))
            stack.enter_context(patch.object(workflow, 'verify'))

            def native_job(output, name, script, args, **kwargs):
                (output / 'capture').mkdir(exist_ok=True)
                if name == 'accessory_measurements':
                    state.update(FRESHNESS_FIXTURE['after'])

            stack.enter_context(patch.object(workflow, 'native_job', side_effect=native_job))
            with self.assertRaisesRegex(ValueError, 'inputs changed since preparation'):
                workflow.build(FRESHNESS_FIXTURE['run_id'])
            self.assertEqual(json.loads((output / 'input_sha256.json').read_text()), FRESHNESS_FIXTURE['before'])
            self.assertFalse((output / 'acceptance.json').exists())

    def test_verify_rejects_changed_dependencies_before_inspecting_cached_results(self):
        with tempfile.TemporaryDirectory(prefix='mq11-verify-freshness-', dir=PROJECT) as temporary, ExitStack() as stack:
            output = Path(temporary)
            spec = {'id': FRESHNESS_FIXTURE['figure']}
            verification_fixture(stack, output, spec, FRESHNESS_FIXTURE['after'])
            inspector = stack.enter_context(patch.object(workflow, 'inspect', return_value={'passed': True}))
            with self.assertRaisesRegex(ValueError, 'inputs changed since preparation'):
                workflow.verify(FRESHNESS_FIXTURE['run_id'])
            inspector.assert_not_called()

    def test_verify_rejects_receipt_rebound_to_different_preparation_inputs(self):
        with tempfile.TemporaryDirectory(prefix='mq11-rebound-', dir=PROJECT) as temporary, ExitStack() as stack:
            output = Path(temporary)
            spec = {'id': FRESHNESS_FIXTURE['figure']}
            verification_fixture(stack, output, spec, FRESHNESS_FIXTURE['before'])
            receipt = json.loads((output / 'acceptance.json').read_text())
            receipt['inputs_sha256'] = FRESHNESS_FIXTURE['after']
            write(output / 'acceptance.json', receipt)
            with self.assertRaisesRegex(ValueError, 'stale mq-11 acceptance'):
                workflow.verify(FRESHNESS_FIXTURE['run_id'])


class NativeShapeBindingTests(unittest.TestCase):
    def test_shape_report_spec_binding_rejects_an_otherwise_current_report(self):
        with tempfile.TemporaryDirectory(prefix='mq11-shape-binding-', dir=PROJECT) as temporary:
            capture = Path(temporary) / 'capture'
            spec = native_capture(capture)
            self.assertTrue(proof.inspect_shape(spec, capture)['passed'])
            shape = json.loads((capture / 'mq11_shape.json').read_text())
            shape['spec_hash'] = 'different spec'
            write(capture / 'mq11_shape.json', shape)
            with (patch.object(proof, 'load_render', side_effect=AssertionError('Stale shape reached image validation')),
                  self.assertRaisesRegex(ValueError, 'Stale native accessory measurements')):
                proof.inspect(spec, capture)

    def test_mesh_export_is_bound_to_the_spec_and_artifact_hashes(self):
        for field in ('spec_hash', 'cold_mesh_hash', 'build_report_sha256', 'blend_sha256'):
            with self.subTest(field=field), tempfile.TemporaryDirectory(prefix='mq11-mesh-binding-', dir=PROJECT) as temporary:
                capture = Path(temporary) / 'capture'
                spec = native_capture(capture)
                exported = json.loads((capture / 'mq11_meshes.json').read_text())
                exported[field] = 'different native input'
                write(capture / 'mq11_meshes.json', exported)
                shape = json.loads((capture / 'mq11_shape.json').read_text())
                shape['mesh_export_sha256'] = sha(capture / 'mq11_meshes.json')
                write(capture / 'mq11_shape.json', shape)
                with self.assertRaisesRegex(ValueError, 'Stale native accessory measurements'):
                    proof.inspect_shape(spec, capture)

    def test_verify_recomputes_measurements_and_rejects_stale_passing_numbers(self):
        with tempfile.TemporaryDirectory(prefix='mq11-shape-replay-', dir=PROJECT) as temporary, ExitStack() as stack:
            output = Path(temporary)
            capture = output / 'capture'
            spec = native_capture(capture)
            verification_fixture(stack, output, spec, FRESHNESS_FIXTURE['before'])
            stack.enter_context(patch.object(workflow, 'inspect', side_effect=lambda spec, capture, **kwargs:
                                           proof.inspect_shape(spec, capture)))
            replay = stack.enter_context(patch.object(proof, 'measure', wraps=measurements.measure))
            workflow.verify(FRESHNESS_FIXTURE['run_id'])
            self.assertEqual(replay.call_count, 1)
            exported = json.loads((capture / 'mq11_meshes.json').read_text())
            matrix, _, basis, scale = camera(spec, 'front')
            shift = (basis[0] @ matrix[:3, :3]) * FIXTURE['attachment_shift_px'] * scale / 1024
            vertices = np.array(exported['meshes']['leather_apron']['vertices']) + shift
            exported['meshes']['leather_apron']['vertices'] = vertices.tolist()
            write(capture / 'mq11_meshes.json', exported)
            shape = json.loads((capture / 'mq11_shape.json').read_text())
            shape['mesh_export_sha256'] = sha(capture / 'mq11_meshes.json')
            write(capture / 'mq11_shape.json', shape)
            with self.assertRaisesRegex(ValueError, 'recomputed shape differs'):
                workflow.verify(FRESHNESS_FIXTURE['run_id'])


if __name__ == '__main__':
    unittest.main()
