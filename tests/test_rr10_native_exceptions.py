"""Director-reviewed rr-13 exceptions never widen to a clip or another rule."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest, read_json
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_exceptions import (
    DETACHED_RULE, JOINT_HOLE_RULE, METRIC_RULES, frame_errors, load)

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
UNLISTED_HOLE_FRAME = 18
UNLISTED_DETACHED_FRAME = 13


def metrics(**changed):
    return dict.fromkeys(METRIC_RULES, 0) | changed


class NativeExceptionTests(unittest.TestCase):
    def test_case_list_contains_exactly_the_39_director_reviewed_flags(self):
        groups = [
            ('front', 'bolt', [20], JOINT_HOLE_RULE),
            ('front', 'death', [62], JOINT_HOLE_RULE),
            ('front', 'hit', [4, 8, 9], JOINT_HOLE_RULE),
            ('front', 'move', [7], JOINT_HOLE_RULE),
            ('front', 'move', [11, 12, 15], DETACHED_RULE),
            ('rear', 'mark', [10, 19, *range(23, 49), 51], JOINT_HOLE_RULE),
            ('rear', 'move', [10], DETACHED_RULE),
        ]
        expected = {(view, clip, frame, rule) for view, clip, frames, rule in groups for frame in frames}
        self.assertEqual(len(expected), 39)
        self.assertEqual(load(CASE), expected)
        for view, clip, frame, rule in expected:
            metric = metrics(stray_components=1 if rule == DETACHED_RULE else 0)
            holes = [2] if rule == JOINT_HOLE_RULE else []
            self.assertEqual(frame_errors((view, clip, frame), metric, holes, load(CASE)), [])

    def test_unlisted_frame_in_listed_clip_still_fails(self):
        for key, metric, holes, rule in [
            (('rear', 'mark', UNLISTED_HOLE_FRAME), metrics(), [2], JOINT_HOLE_RULE),
            (('front', 'move', UNLISTED_DETACHED_FRAME), metrics(stray_components=1), [], DETACHED_RULE),
        ]:
            with self.subTest(key=key):
                self.assertEqual(frame_errors(key, metric, holes, load(CASE)), [str(key) + ': ' + rule])

    def test_listed_frame_does_not_exempt_another_rule_or_view(self):
        approved = load(CASE)
        key = ('front', 'move', 7)
        self.assertEqual(frame_errors(key, metrics(stray_components=1), [2], approved),
                         [str(key) + ': ' + DETACHED_RULE])
        for name, rule in METRIC_RULES.items():
            if rule == DETACHED_RULE:
                continue
            self.assertEqual(frame_errors(key, metrics(**{name: 1}), [2], approved),
                             [str(key) + ': ' + rule])
        key = ('front', 'mark', 10)
        self.assertEqual(frame_errors(key, metrics(), [2], approved), [str(key) + ': ' + JOINT_HOLE_RULE])

    def test_missing_list_exempts_nothing_and_malformed_entries_are_rejected(self):
        row = read_json(CASE / 'gate_exceptions.json')[0]
        with tempfile.TemporaryDirectory(prefix='rr13-exception-data-') as folder:
            case = Path(folder)
            self.assertEqual(load(case), frozenset())
            key = ('front', 'bolt', 20)
            self.assertEqual(frame_errors(key, metrics(), [2], load(case)), [str(key) + ': ' + JOINT_HOLE_RULE])
            for field, value in [('frames', ['23-48']), ('frames', [True]), ('frames', [20, 20]),
                                 ('reason', ''), ('rule', 'joint-seam hole'), ('view', '*')]:
                invalid = copy.deepcopy(row)
                invalid[field] = value
                (case / 'gate_exceptions.json').write_text(json.dumps([invalid]))
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    load(case)

    def test_exception_data_participates_in_native_freshness_bindings(self):
        self.assertEqual(bindings(CASE)['gate_exceptions.json'], digest(CASE / 'gate_exceptions.json'))


if __name__ == '__main__':
    unittest.main()
