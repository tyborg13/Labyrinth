"""Prove the four surviving review mutations now fail behavioral tests in memory."""
import io
from pathlib import Path
import unittest
from unittest.mock import patch

from spec.art_identity.maquettes.blender.accessory_geometry import forms
from spec.art_identity.maquettes.hollow_mimic.owner_review import candidate, proof, workflow


MUTATIONS = {
    'flap_row_ordering': (
        forms, 'flap_piece', candidate,
        "if any(b['drop_fraction'] <= a['drop_fraction'] for a, b in zip(source, source[1:])):", 'if False:',
        'tests.test_mq11_validation.GeometryReviewTests.test_reversed_or_duplicate_internal_flap_rows_fail'),
    'unowned_accessory_preservation': (
        candidate, 'assert_preserved', candidate,
        "if [p for p in before['pieces'] if p['id'] not in changed] != [p for p in after['pieces'] if p['id'] not in changed]:", 'if False:',
        'tests.test_mq11_validation.GeometryReviewTests.test_mutated_unowned_accessory_is_rejected_independently_of_body_fields'),
    'acceptance_freshness': (
        workflow, 'require_current_inputs', workflow,
        'if inputs() != snapshot:', 'if False:',
        'tests.test_mq11_freshness.AcceptanceFreshnessTests.test_verify_rejects_changed_dependencies_before_inspecting_cached_results'),
    'shape_report_spec_binding': (
        proof, 'inspect_shape', proof,
        "shape = json.loads((capture / 'mq11_shape.json').read_text())",
        "shape = json.loads((capture / 'mq11_shape.json').read_text())\n    shape['spec_hash'] = digest(spec)",
        'tests.test_mq11_freshness.NativeShapeBindingTests.test_shape_report_spec_binding_rejects_an_otherwise_current_report'),
}


class GuardMutationTests(unittest.TestCase):
    def test_all_four_review_mutations_are_caught_by_assertions(self):
        for name, (source, function, target, before, after, test_name) in MUTATIONS.items():
            with self.subTest(mutation=name):
                code = Path(source.__file__).read_text()
                self.assertEqual(code.count(before), 1, 'Mutation target must be unique')
                namespace = dict(source.__dict__)
                exec(compile(code.replace(before, after), source.__file__, 'exec'), namespace)
                suite = unittest.defaultTestLoader.loadTestsFromName(test_name)
                stream = io.StringIO()
                with patch.object(target, function, namespace[function]):
                    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
                self.assertFalse(result.errors, stream.getvalue())
                self.assertGreaterEqual(len(result.failures), 1, stream.getvalue())
                print('MQ11_MUTATION_CAUGHT: ' + name + '; errors=0')


if __name__ == '__main__':
    unittest.main()
