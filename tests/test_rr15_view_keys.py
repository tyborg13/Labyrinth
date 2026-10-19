"""Whole-channel view replacement, legacy preservation and real sampling."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json
from humanoid_cutout.compiler import compile_motion, keys_for_view

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-15')
THRALL = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
SEER = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-11/motion_tracks.json'
PROOF_TASK_ID = 'rr-15'
PROOF_TIMEOUT_SECONDS = 180
RELEASE_PHASE_DIVISOR = 2


def compile_fixture(author, creature, case, folder):
    path = folder / (creature + '.json')
    path.write_text(json.dumps(author))
    old = read_json(case / 'compiled_motion.json')
    layouts = {view: read_json(case / f'layouts/{view}.json') for view in old['view_tracks']}
    return compile_motion(path, creature, layouts, old['projection'])


class ViewKeyTests(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        self.folder = tempfile.TemporaryDirectory(prefix='view-keys-', dir=SCRATCH)
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name)
        self.source = read_json(DIRECTOR)

    def test_replacement_is_whole_channel_and_other_views_and_metadata_are_unchanged(self):
        actual = compile_fixture(self.source, 'arc_thrall', THRALL, self.path)
        base_source = copy.deepcopy(self.source)
        for definition in base_source['arc_thrall']['clips'].values():
            definition.pop('view_keys', None)
        base = compile_fixture(base_source, 'arc_thrall', THRALL, self.path)
        self.assertEqual(actual['view_tracks']['front'], base['view_tracks']['front'])
        self.assertEqual(actual['clips'], base['clips'])
        for clip, tracks in actual['view_tracks']['rear'].items():
            by_source = {t['source']: t for t in base['view_tracks']['rear'][clip]}
            overrides = self.source['arc_thrall']['clips'][clip].get('view_keys', {}).get('rear', {})
            for track in tracks:
                if track['source'] not in overrides:
                    self.assertEqual(track, by_source[track['source']])
                else:
                    self.assertEqual([(r['at'], r['value']) for r in track['keys']],
                                     [tuple(row[:2]) for row in overrides[track['source']]])
        self.assertEqual(self.source, read_json(DIRECTOR))

    def test_mode_override_resolves_roles_and_malformed_view_maps_are_rejected(self):
        source = copy.deepcopy(self.source)
        move = source['arc_thrall']['clips']['move']
        move['view_keys'] = {'rear': {'foot_stride.forward_mode': 'body'}}
        data = compile_fixture(source, 'arc_thrall', THRALL, self.path)
        rear = next(t for t in data['view_tracks']['rear']['move'] if t['source'] == 'foot_stride.forward_px')
        front = next(t for t in data['view_tracks']['front']['move'] if t['source'] == 'foot_stride.forward_px')
        self.assertEqual((rear['bone'], rear['forward_mode']), ('foot_far', 'body'))
        self.assertEqual(front['forward_mode'], 'world_step')
        self.assertEqual(data['view_forward_modes']['rear']['move']['foot_far'], 'body')
        for invalid in ({'rear_typo': {}}, {'rear': []}, []):
            with self.assertRaisesRegex(ValueError, 'view_keys'):
                keys_for_view({'keys': {}, 'view_keys': invalid}, 'rear', ('front', 'rear'))

    def test_compiler_keeps_legacy_seer_data_identical(self):
        old = read_json(SEER / 'compiled_motion.json')
        source = PROJECT / 'spec/peer_benchmark/staged/rr-10/motion_tracks.json'
        layouts = {v: read_json(SEER / f'layouts/{v}.json') for v in old['view_tracks']}
        self.assertEqual(compile_motion(source, 'hoarfrost_seer', layouts, old['projection']), old)

    def test_runtime_samples_rear_numeric_overrides_and_isolates_release_policy(self):
        author = read_json(SEER / 'director_motion.json')
        death = author['hoarfrost_seer']['clips']['death']
        base_release = death['keys']['staff.release_at']
        rear_release = base_release / RELEASE_PHASE_DIVISOR
        death['view_keys'] = {'rear': {'staff.release_at': rear_release}}
        release = compile_fixture(author, 'hoarfrost_seer', SEER, self.path)
        self.assertEqual(release['clips']['death']['release_at']['staff'], base_release)
        self.assertEqual(release['view_release_at']['front']['death']['staff'], base_release)
        self.assertEqual(release['view_release_at']['rear']['death']['staff'], rear_release)
        channels = {}
        for view in ('front', 'rear'):
            channels[view] = [
                {'clip': 'jab', 'phase': .3, 'forward_px': -10, 'lift_px': 8},
                {'clip': 'jab', 'phase': .45, 'forward_px': 100 if view == 'front' else 209,
                 'lift_px': 59 if view == 'front' else 50},
                {'clip': 'jab', 'phase': .65, 'forward_px': 85 if view == 'front' else 178,
                 'lift_px': 50 if view == 'front' else 43},
                {'clip': 'tether', 'phase': .35, 'forward_px': 125 if view == 'front' else 206,
                 'lift_px': 92 if view == 'front' else 63},
                {'clip': 'tether', 'phase': .8, 'forward_px': 125 if view == 'front' else 206,
                 'lift_px': 92 if view == 'front' else 63}]
        fixture = self.path / 'runtime.json'
        fixture.write_text(json.dumps({'thrall': read_json(THRALL / 'compiled_motion.json'),
            'release': release, 'release_phase': (base_release + rear_release) / 2, 'channels': channels}))
        result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID,
            '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr11/view_key_checks.gd',
            '--', '--fixture', str(fixture)], cwd=PROJECT, capture_output=True, text=True,
            timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('RR15 VIEW KEY RUNTIME: PASS (22 checks)', result.stdout)


if __name__ == '__main__':
    unittest.main()
