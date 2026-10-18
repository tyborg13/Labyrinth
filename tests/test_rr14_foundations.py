"""Second anatomy exercises the same compiler, gates, ownership and runtime."""
import json
import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, call
import shutil

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'tests/rr14')]
from fixture import build
from humanoid_cutout.anatomy import load
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings, idle_group_offset
from humanoid_cutout.materials import held_depths
from humanoid_cutout.silhouette_gates import posed_owners
from humanoid_cutout.integration import record

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-14')
PROOF_TIMEOUT_SECONDS = 180
SEER = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'


class FoundationTests(unittest.TestCase):
    def test_case_hierarchy_and_mesh_guards(self):
        with tempfile.TemporaryDirectory(prefix='guards-', dir=SCRATCH) as folder:
            layout, _, report, _ = build(Path(folder))
            wrong_parent = copy.deepcopy(layout)
            wrong_parent['joints']['foot_near']['parent'] = 'pelvis'
            self.assertIn('hierarchy: foot_near', structure_errors(wrong_parent, report))
            missing_mesh = copy.deepcopy(layout)
            missing_mesh['joint_meshes'] = [m for m in missing_mesh['joint_meshes'] if m['name'] != 'loincloth']
            self.assertTrue(any('cut: required meshes differ' in e for e in structure_errors(missing_mesh, report)))

    def test_native_idle_offset_uses_the_lagged_weapon_group_anchor(self):
        with tempfile.TemporaryDirectory(prefix='idle-anchor-', dir=SCRATCH) as folder:
            layout, anatomy, _, _ = build(Path(folder))
            bones = {n: {'global': [1, 0, 0, 1, *j['position']]} for n, j in layout['joints'].items()}
            for name in anatomy['idle_groups']['weapon_arm']['bones']:
                bones[name]['global'][5] += 2
            np.testing.assert_array_equal(idle_group_offset(layout, bones, 'weapon_arm', anatomy), [0, 2])
            np.testing.assert_array_equal(idle_group_offset(layout, bones, 'upper_body', anatomy), [0, 0])
            np.testing.assert_array_equal(idle_group_offset(layout, bones, 'lower_body', anatomy), [0, 0])

    def test_second_anatomy_compiler_gates_and_headless_runtime(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='anatomy-', dir=SCRATCH) as folder:
            case = Path(folder)
            layout, anatomy, report, compiled = build(case)
            self.assertEqual(structure_errors(layout, report), [])
            self.assertEqual(source_errors(case, layout, report), [])
            self.assertEqual(set(compiled['view_tracks']), {'front', 'rear'})
            self.assertNotIn('robe', anatomy['meshes'])
            self.assertEqual(set(anatomy['meshes']), {'arm_near', 'arm_far', 'leg_near', 'leg_far', 'loincloth'})
            for mesh in layout['joint_meshes']:
                for values in mesh['weights'].values():
                    self.assertGreater(max(values), 0, 'fixture must actually exercise each skinned bone')
            self.assertNotIn('hand_near', layout['joints'])
            self.assertEqual(layout['joints']['loincloth']['parent'], 'pelvis')
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-14', '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', 'tests/rr14/runtime_checks.gd', '--',
                       '--case', folder, '--report', str(case / 'proof/samples.json')]
            result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            (SCRATCH / 'synthetic-runtime.log').write_text(result.stdout + result.stderr)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('RR14 RUNTIME: PASS', result.stdout)
            samples = json.loads((case / 'proof/samples.json').read_text())
            for view in compiled['view_tracks']:
                view_layout = json.loads((case / ('layouts/' + view + '.json')).read_text())
                self.assertEqual(structure_errors(view_layout, report), [])
                self.assertEqual(source_errors(case, view_layout, report), [])
                self.assertEqual(bone_errors(view_layout, compiled, samples, bindings(case)), [])
            bad_bones = copy.deepcopy(samples)
            swing = next(r for r in bad_bones['samples'] if r['kind'] == 'authored' and r['clip'] == 'move' and r['phase'] == .5)
            swing['bones']['foot_near']['global'][4] += 1
            self.assertTrue(any('IK length' in error for error in bone_errors(layout, compiled, bad_bones, bindings(case))))
            print(next(line for line in result.stdout.splitlines() if line.startswith('RR14 RUNTIME:')))
            # Ownership needs only the case's arbitrary names and chain roles.
            bones = {n: {'global': [1, 0, 0, 1, *j['position']]} for n, j in layout['joints'].items()}
            paint = np.zeros((32, 32, 4), dtype=np.uint8); paint[20:25, 20:24] = 255
            owners = posed_owners([({'name': 'leg_near', 'z_index': 0}, paint, None)],
                                  layout['parts'], bones, [0, 0], anatomy['ownership'])
            self.assertGreater((owners > 0).sum(), 0)

    def test_case_held_item_rename_uses_data_without_key_error(self):
        # Exercise the exact historical failure as well as the second case.
        layout = json.loads((SEER / 'layouts/front.json').read_text())
        anatomy = load(SEER)
        def rename(value):
            if isinstance(value, dict): return {rename(k): rename(v) for k, v in value.items()}
            if isinstance(value, list): return [rename(v) for v in value]
            return value.replace('staff', 'horn') if isinstance(value, str) else value
        layout, anatomy = rename(layout), rename(anatomy)
        layout['anatomy'] = anatomy
        report = json.loads((SEER / 'proof/build.json').read_text())
        self.assertEqual(structure_errors(layout, report), [])
        depths = {p['name']: p['z_index'] for p in layout['parts']}
        self.assertIn('horn', held_depths(depths, 'front', anatomy['held_depth_roles']))
        with tempfile.TemporaryDirectory(prefix='renamed-', dir=SCRATCH) as folder:
            layout, anatomy, report, compiled = build(Path(folder), item='horn')
            self.assertEqual(structure_errors(layout, report), [])
            self.assertEqual(source_errors(Path(folder), layout, report), [])

    def test_production_binding_comes_from_the_case(self):
        with tempfile.TemporaryDirectory(prefix='bindings-', dir=PROJECT / 'tests/rr14') as folder:
            case = Path(folder)
            build(case)
            config = load(case)
            config['integration']['rig_directory'] = 'bound-assets'
            (case / 'bound-assets').mkdir()
            (case / 'bound-assets/token.json').write_text('{}')
            # A task-local project-relative root proves no production identity
            # can accidentally be inherited from another case.
            config['integration']['production_root'] = str(case.relative_to(PROJECT))
            (case / 'anatomy.json').write_text(json.dumps(config))
            current = bindings(case)
            self.assertIn('production:' + str((case / 'bound-assets/token.json').relative_to(PROJECT)), current)
            self.assertFalse(any('hoarfrost' in key for key in current))

    def test_integration_uses_case_scale_identity_and_density_targets(self):
        with tempfile.TemporaryDirectory(prefix='integration-', dir=SCRATCH) as folder:
            project = Path(folder)
            case, assets = project / 'case', project / 'assets'
            build(case)
            config = load(case)
            config['integration'].update(production_root='assets', rig_directory='diagnostic_rig',
                production_files=[], scale={'file': 'scale.json', 'key': 'fixture', 'field': 'scale', 'default': 1.0},
                identity_registry='identity.json', identity_id='fixture_identity', identity_kind='creature',
                identity_entry_kind='legacy', identity_boss=False, density_id='fixture_density',
                owner_approval='diagnostic fixture only')
            def write(path, value):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(value))
            write(case / 'anatomy.json', config)
            write(case / 'inputs.json', {'front_job': 'job', 'rear_job': 'job'})
            write(case / 'proof/build.json', {'views': {v: {'rest_mismatch_pixels': 0} for v in ('front', 'rear')}})
            write(project / 'job/kit.json', {'anatomy': 'fixture', 'size_class': 'fixture'})
            write(project / 'job/processed.json', {'pixel_sha256': 'fixture_source'})
            write(project / 'scale.json', {'fixture': {'scale': 1.25}})
            write(project / 'identity.json', {'entries': []})
            write(project / 'density.json', {})
            rests = [assets / ('diagnostic_rig/' + view + '/rest.png') for view in ('front', 'rear')]
            for rest in rests:
                rest.parent.mkdir(parents=True)
                shutil.copyfile(case / 'rest.png', rest)
            with patch('humanoid_cutout.integration.density.load_registry', return_value={'entries': [{'id': 'fixture_density'}]}), \
                    patch('humanoid_cutout.integration.density.MANIFEST', project / 'density.json'), \
                    patch('humanoid_cutout.integration.density.rest_errors', return_value=[]) as density_check, \
                    patch('humanoid_cutout.integration.measure', return_value={}) as measure:
                self.assertEqual(record(project, case, assets), [])
                self.assertEqual(measure.call_count, 2)
                measure.assert_has_calls([call(rest, 1.25, 'creature', 'fixture') for rest in rests])
                self.assertEqual(density_check.call_args.args[0], [{'id': 'fixture_density'}])
            identity = json.loads((project / 'identity.json').read_text())['entries'][0]
            self.assertEqual(identity['id'], 'fixture_identity')
            self.assertEqual(identity['art_scale'], 1.25)
            integrated = json.loads((assets / 'integration.json').read_text())
            self.assertEqual(integrated['density']['entry'], 'fixture_density')
            self.assertEqual(integrated['rest_identity']['front'], 0)


if __name__ == '__main__':
    unittest.main()
