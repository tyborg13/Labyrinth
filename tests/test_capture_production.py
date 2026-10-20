"""Real-time production matching and combined-view canonical gate input."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from capture_production import combined, compare_production, validate_manifest
from capture_gate_runner import run_production
from humanoid_cutout.gates import bindings


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data))


class ProductionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='cap01-production-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.case = self.root / 'rr10'
        write_json(self.case / 'compiled_motion.json', {'clips': {'hit': {'seconds': .5}}})

    def save(self, root, phases, *, hashes=None, stage='hit', view='front'):
        rows = [{'stage': stage, 'file': f'frame_{i:05d}_{stage}.png', 'pixels_sha256': (hashes or {}).get(p, str(p)),
                 'snapshot': {'phase': p, 'presented_phase': p, 'facing': view, 'clip': stage, 'rig_count': 2}}
                for i, p in enumerate(phases)]
        manifest = {'ok': True, 'errors': [], 'frames': rows, 'inputs': {}, 'native_pixels': True,
                    'size': [1920, 1080], 'ui_scale': 1, 'completions': {'hit': {'clip': 'idle'}}}
        write_json(root / view / 'frames.json', manifest)
        return manifest

    def compare(self, left, right):
        return compare_production(self.case, left, right, phase_field='phase')

    def test_one_or_two_extra_frames_are_listed_per_side(self):
        a, b = self.root / 'before', self.root / 'after'
        self.save(a, [0, .1, .2, .3, 1]); self.save(b, [0, .2, .4, .5, 1])
        result = self.compare(a, b)
        self.assertTrue(result['ok'], result['errors'])
        row = result['clips'][0]
        self.assertEqual(row['matched'], 3)
        self.assertEqual([r['phase'] for r in row['unmatched_before']], [.1, .3])
        self.assertEqual([r['phase'] for r in row['unmatched_after']], [.4, .5])

    def test_third_extra_frame_fails_and_names_files(self):
        a, b = self.root / 'before', self.root / 'after'
        self.save(a, [0, .1, .2, .3, 1]); self.save(b, [0, 1])
        result = self.compare(a, b)
        self.assertFalse(result['ok'])
        self.assertIn('3 unmatched', result['errors'][0])
        self.assertIn('frame_00001_hit.png', result['errors'][0])

    def test_unmatched_allowance_is_per_clip_across_both_views(self):
        case = self.root / 'rr22'; write_json(case / 'compiled_motion.json', {'clips': {'hit': {'seconds': .5}}})
        a, b = self.root / 'before', self.root / 'after'
        for view in ('front', 'rear'):
            self.save(a, [0, .2, 1], view=view); self.save(b, [0, 1], view=view)
        self.assertTrue(compare_production(case, a, b, phase_field='phase')['ok'])
        self.save(a, [0, .1, .2, 1], view='front')
        result = compare_production(case, a, b, phase_field='phase')
        self.assertFalse(result['ok'])
        self.assertIn('3 unmatched', result['errors'][0])

    def test_hash_mutation_in_any_matched_frame_fails(self):
        a, b = self.root / 'before', self.root / 'after'
        self.save(a, [0, .5, 1]); self.save(b, [0, .5, 1], hashes={.5: 'mutated'})
        result = self.compare(a, b)
        self.assertFalse(result['ok'])
        self.assertIn('Renderer texture hash differs', result['errors'][0])

    def test_duplicate_phase_occurrences_are_not_collapsed_or_matched_by_hash(self):
        a, b = self.root / 'before', self.root / 'after'
        self.save(a, [0, .5, .5, 1]); manifest = self.save(b, [0, .5, .5, .5, 1])
        self.assertTrue(self.compare(a, b)['ok'])
        manifest['frames'][1]['pixels_sha256'] = 'mutated'
        write_json(b / 'front/frames.json', manifest)
        self.assertFalse(self.compare(a, b)['ok'])

    def test_no_common_frames_or_invalid_phase_cannot_pass(self):
        a, b = self.root / 'before', self.root / 'after'
        self.save(a, [.1, .2]); self.save(b, [.3, .4])
        self.assertFalse(self.compare(a, b)['ok'])
        self.save(b, [float('nan')])
        with self.assertRaises(ValueError): self.compare(a, b)

    def test_named_phase_field_preserves_explicit_matching_policy(self):
        a, b = self.root / 'before', self.root / 'after'
        self.save(a, [0, .5, 1]); manifest = self.save(b, [0, .5, 1])
        for row in manifest['frames']: row['snapshot']['phase'] += .001
        write_json(b / 'front/frames.json', manifest)
        result = compare_production(self.case, a, b, phase_field='presented_phase')
        self.assertTrue(result['ok'])
        self.assertEqual(result['identity'], ['view', 'stage', 'presented_phase'])

    def test_completeness_uses_observed_phases_contacts_and_manifest_errors(self):
        manifest = self.save(self.root / 'coverage', [0, .2, .5, .8, 1])
        data = {'clips': {'hit': {'seconds': .5, 'contact': .5}}}
        report = validate_manifest(manifest, data, Path('frames.json'))
        self.assertEqual(report['hit']['frames'], 5)
        for mode in ('missing_contact', 'narrow_span', 'invalid_domain', 'capture_error', 'missing_clip'):
            value = copy.deepcopy(manifest)
            if mode == 'missing_contact': value['frames'] = [r for r in value['frames'] if r['snapshot']['phase'] != .5]
            elif mode == 'narrow_span':
                for row in value['frames']: row['snapshot']['phase'] = .5
            elif mode == 'invalid_domain': value['frames'][0]['snapshot']['phase'] = -.1
            elif mode == 'capture_error': value['errors'] = ['capture failed']
            else: value['frames'] = []
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                validate_manifest(value, data, Path('frames.json'))

    def production_fixture(self):
        case = PROJECT / 'experiments/cutouts/slag_mortar/rr22'
        data = json.loads((case / 'compiled_motion.json').read_bytes())
        capture = self.root / 'combined'
        for view in ('front', 'rear'):
            rows = []
            for stage, definition in data['clips'].items():
                phases = sorted({0., .2, .4, .6, .8, 1., definition.get('contact', 0.)})
                for i, phase in enumerate(phases):
                    rows.append({'stage': stage, 'file': f'{stage}_{i}.png', 'pose_sha256': str(i),
                        'pixels_sha256': str(i), 'snapshot': {'phase': phase, 'facing': view, 'clip': stage, 'rig_count': 2}})
            manifest = {'ok': True, 'errors': [], 'frames': rows, 'inputs': bindings(case), 'native_pixels': True,
                        'size': [1920, 1080], 'ui_scale': 1, 'completions': {'hit': {'clip': 'idle'}},
                        'walk_samples': {view: {'test_view': view}}}
            write_json(capture / view / 'frames.json', manifest)
        return case, capture

    def test_combined_gate_sees_both_views_and_records_one_verdict(self):
        case, capture = self.production_fixture()
        merged = combined(case, capture)
        self.assertEqual(set(merged['walk_samples']), {'front', 'rear'})
        self.assertEqual(set(merged['capture_counts']), {'front', 'rear'})
        with patch('humanoid_cutout.walk_gates.report', return_value={'errors': []}) as walk:
            code = run_production(case, capture, capture)
        self.assertEqual(code, 0)
        self.assertEqual({call.args[0]['facing'] for call in walk.call_args_list}, {'front', 'rear'})
        self.assertEqual(json.loads((capture / 'production_gates.json').read_text()), {'ok': True, 'errors': []})
        self.assertFalse((capture / 'front/production_gates.json').exists())

    def test_combination_does_not_hide_a_real_within_view_restart(self):
        case, capture = self.production_fixture()
        path = capture / 'front/frames.json'; manifest = json.loads(path.read_text())
        rows = [row for row in manifest['frames'] if row['stage'] == 'lob']
        rows[2]['snapshot']['phase'] = 0
        write_json(path, manifest)
        with patch('humanoid_cutout.walk_gates.report', return_value={'errors': []}):
            self.assertEqual(run_production(case, capture, capture), 1)
        self.assertIn('lob: clip restarted during one action', json.loads((capture / 'production_gates.json').read_text())['errors'])


if __name__ == '__main__': unittest.main()
