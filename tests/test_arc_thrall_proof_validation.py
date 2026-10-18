"""Adversarial mq-07 receipts must fail before any curation mutation."""
from copy import deepcopy
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from spec.art_identity.maquettes.arc_thrall.r2 import curate
from spec.art_identity.maquettes.arc_thrall.r2.gate_receipt import binding, POSE_CHECKS, TUBE_CHECKS
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import inventory, sha

FIGURE = Path(__file__).resolve().parents[1] / 'spec/art_identity/maquettes/arc_thrall'
PROOF_FIXTURE = {'stale_sha256': '0' * 64, 'evidence_bytes': b'retained native evidence fixture'}


class FirstMutation(Exception):
    pass


class AcceptedDeliveryTests(unittest.TestCase):
    def test_accepted_geometry_and_images_are_byte_identical(self):
        locked = json.loads((FIGURE / 'r2/proof/feedback3_geometry_lock.json').read_text())
        for name, expected in locked.items():
            with self.subTest(file=name):
                self.assertEqual(sha(FIGURE / name), expected)


class CurationEvidenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.figure = Path(temporary.name) / 'arc_thrall'
        self.root = self.figure / 'r2/proof'
        self.root.mkdir(parents=True)
        self.capture = self.root / 'capture'
        shutil.copytree(FIGURE / 'delivery', self.capture)
        shutil.copyfile(FIGURE / 'r2/measurements.json', self.root.parent / 'measurements.json')
        for name in ('gates.json', 'tube_geometry.json', 'shoulder_tube_sheet.png'):
            shutil.copyfile(FIGURE / 'r2/proof' / name, self.root / name)
        self.spec = compile_recipe(json.loads((self.root.parent / 'measurements.json').read_text()))
        self.original = json.loads((self.root / 'gates.json').read_text())
        for folder in (self.figure / 'delivery', self.root / 'native'):
            folder.mkdir(exist_ok=True)
            (folder / 'retained.blend').write_bytes(PROOF_FIXTURE['evidence_bytes'])

    def write(self, data):
        (self.root / 'gates.json').write_text(json.dumps(data))

    def untouched_rejection(self):
        before = {str(path.relative_to(self.figure)): sha(path) for path in inventory(self.figure)}
        with patch.object(curate, 'FIGURE', self.figure), patch.object(curate, 'discard_evidence') as discard, \
                patch.object(curate, 'stage') as stage:
            with self.assertRaises((ValueError, OSError)):
                curate.main()
            discard.assert_not_called()
            stage.assert_not_called()
        self.assertEqual(before, {str(path.relative_to(self.figure)): sha(path)
                                  for path in inventory(self.figure)})

    def test_current_receipt_reaches_first_mutation(self):
        with patch.object(curate, 'FIGURE', self.figure), \
                patch.object(curate, 'discard_evidence', side_effect=FirstMutation) as discard:
            with self.assertRaises(FirstMutation):
                curate.main()
            discard.assert_called_once()

    def test_stale_spec_capture_or_tube_hash_preserves_every_file(self):
        fields = [('spec_hash',), ('binding', 'spec_hash'), ('binding', 'capture_manifest_sha256'),
                  ('binding', 'recipe_sha256'), ('binding', 'tube_receipt_sha256'),
                  ('binding', 'report_sha256', 'capture_checks.json')]
        for keys in fields:
            with self.subTest(field=keys):
                data = deepcopy(self.original)
                parent = data
                for key in keys[:-1]:
                    parent = parent[key]
                parent[keys[-1]] = PROOF_FIXTURE['stale_sha256']
                self.write(data)
                self.untouched_rejection()

    def test_missing_receipt_preserves_every_file(self):
        for name in ('gates.json', 'tube_geometry.json'):
            with self.subTest(receipt=name):
                path = self.root / name
                before = path.read_bytes()
                path.unlink()
                self.untouched_rejection()
                path.write_bytes(before)

    def test_each_mandatory_false_gate_preserves_every_file(self):
        fields = [('passed',), ('native_delivery_passed',), ('native_tube_entry_passed',),
                  ('tube_geometry', 'passed'), ('floor_guard', 'passed'), ('framing', 'passed')]
        fields += [('checks', name) for name in POSE_CHECKS]
        fields += [('tube_geometry', 'checks', name) for name in TUBE_CHECKS]
        for view in ('front', 'rear'):
            fields += [('after_fit', view, 'passed'), ('framing', 'views', view, 'passed'),
                       ('tube_widths', view, 'passed')]
            fields += [('after_fit', view, 'per_part_coverage', name, 'passed') for name in self.spec['labels']]
        for keys in fields:
            with self.subTest(field=keys):
                data = deepcopy(self.original)
                parent = data
                for key in keys[:-1]:
                    parent = parent[key]
                parent[keys[-1]] = False
                self.write(data)
                self.untouched_rejection()

    def test_missing_gate_collections_and_failed_numbers_are_not_vacuous_passes(self):
        fields = [('checks',), ('tube_geometry',), ('floor_guard',), ('after_fit',), ('tube_widths',),
                  ('framing', 'views'), ('after_fit', 'front', 'per_part_coverage')]
        for keys in fields:
            with self.subTest(field=keys):
                data = deepcopy(self.original)
                parent = data
                for key in keys[:-1]:
                    parent = parent[key]
                parent[keys[-1]] = {}
                self.write(data)
                self.untouched_rejection()
        data = deepcopy(self.original)
        data['after_fit']['rear']['fixed_original_iou'] = 0
        self.write(data)
        self.untouched_rejection()

    def test_changed_capture_bytes_and_native_tube_failure_cannot_be_rebound(self):
        path = self.capture / 'capture_frame.json'
        path.write_text(path.read_text() + '\n')
        self.untouched_rejection()
        shutil.copyfile(FIGURE / 'delivery/capture_frame.json', path)
        tube_path = self.root / 'tube_geometry.json'
        original = json.loads(tube_path.read_text())
        for field in ('spec_hash', 'passed', 'native_entry'):
            with self.subTest(field=field):
                tube = deepcopy(original)
                if field == 'native_entry':
                    tube[field]['passed'] = False
                else:
                    tube[field] = PROOF_FIXTURE['stale_sha256'] if field == 'spec_hash' else False
                tube_path.write_text(json.dumps(tube))
                data = deepcopy(self.original)
                data['binding'] = binding(self.spec, self.capture, self.root)
                self.write(data)
                self.untouched_rejection()


if __name__ == '__main__':
    unittest.main()
