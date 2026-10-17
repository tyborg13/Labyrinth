"""Portable v2 contracts plus an opt-in real Blender integration suite."""
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.backend import command, load_render
from spec.art_identity.maquettes.blender.contract import digest, label_faces, mesh_hash, pattern_mesh, todos, validate
from spec.art_identity.maquettes.fitting import fit_spec, measure
from spec.art_identity.maquettes.raster import Raster, project


PROJECT = Path(__file__).resolve().parents[1]
R3 = PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json'


def fixture():
    return {'version': 2, 'base': {'asset': 'debug_body', 'matrix': np.eye(4).tolist()},
            'labels': {'torso': [1, 0, 0]}, 'ortho_scale': 3, 'target': [0, 0, 1],
            'joints': {'pelvis': [0, 0, .4], 'torso': [0, 0, 1], 'head': [0, 0, 2]},
            'armature': {'rest_joints': {'pelvis': [0, 0, .4], 'torso': [0, 0, 1], 'head': [0, 0, 2]},
                         'bones': [{'name': 'torso', 'head': 'torso', 'tail': 'head', 'region': 'torso',
                                    'scale': [1, 1], 'roll': 0}]}, 'pieces': [],
            'fit': {'source_frame': {'head_top': 0, 'sole_bottom': 100, 'ground_x': 50},
                    'landmarks': {'waist': {'y': .5, 'joint': 'torso'}}, 'head_part': 'torso'}}


class NativeContractTests(unittest.TestCase):
    def test_lancer_r3_contains_every_brief_piece_as_source_measured_proposal(self):
        spec = json.loads(R3.read_text())
        ids = {p['id'] for p in spec['pieces']}
        expected = {'hood', 'collar', 'breastplate', 'chest_gem', 'belt', 'diagonal_strap',
                    'tabard_front', 'cloak', 'spear_shaft', 'spear_blade',
                    'face_plate', 'face_slit_accent', 'face_crossbar_accent'}
        expected.update({'boot_near', 'boot_far'})
        for side in ('near', 'far'):
            expected.update(name + '_' + side for name in ('pauldron', 'tasset', 'vambrace', 'gauntlet', 'cuisse', 'poleyn', 'greave', 'sabaton'))
        self.assertEqual(expected, ids)
        self.assertEqual(spec['base']['asset'], 'realistic_body_male')
        r2 = json.loads(R3.with_name('spec_r2.json').read_text())
        for key in ('target', 'ortho_scale', 'fit'):
            self.assertEqual(r2[key], spec[key])
        self.assertTrue(all(spec['labels'][k] == v for k, v in r2['labels'].items()))
        self.assertFalse(todos(spec))
        self.assertTrue(spec['proposed'])
        self.assertTrue(all(p['proposed'] for p in spec['pieces']))
        validate(spec)

    def test_round2_conformance_and_preserved_director_features(self):
        from spec.art_identity.maquettes.blender.propose_lancer import propose
        from spec.art_identity.maquettes.blender.refine_lancer import refine
        original = propose()
        spec = json.loads(R3.read_text())
        from spec.art_identity.maquettes.blender.round3_lancer import refine as round3
        self.assertEqual(round3(refine(original)), spec)
        before = {p['id']: p for p in original['pieces']}
        after = {p['id']: p for p in spec['pieces']}
        round2 = refine(original)
        self.assertEqual(round2['joints'], spec['joints'])
        self.assertEqual(round2['armature'], spec['armature'])
        for p in round2['pieces']:
            if p['type'] in ('plate', 'lames') and p['id'] != 'breastplate':
                self.assertEqual(p['rot'], after[p['id']]['rot'], p['id'])
        for name in ('collar', 'cloak'):
            self.assertEqual(before[name], {k: v for k, v in after[name].items() if k != 'space'})
        for name in ('asset', 'object', 'matrix', 'subdivision_level'):
            self.assertEqual(original['base'][name], spec['base'][name])
        for name, xyz in original['joints'].items():
            if name not in ('hand_near', 'hand_tip_near', 'foot_tip_near', 'foot_tip_far'):
                self.assertEqual(xyz, spec['joints'][name])
        for p in after.values():
            if p['type'] in ('plate', 'lames'):
                self.assertTrue(p['conforming'])
                self.assertNotIn('conform_weights', p)
                self.assertLessEqual(p['offset_surface'] + max(p.get('overlap', [0])), .015)
                if p['type'] == 'lames':
                    self.assertGreater(p['lame_scale'][0][0], p['lame_scale'][-1][0])
        self.assertEqual(len(after['face_plate']['slots']), 2)
        self.assertIn('head', spec['base']['covered_regions'])
        self.assertEqual(after['chest_gem']['sides'], 4)
        self.assertAlmostEqual(after['chest_gem']['length'], before['chest_gem']['length'] * 1.3)
        shaft = after['spear_shaft']
        blade = after['spear_blade']
        length = np.linalg.norm(np.array(shaft['path'][-1]) - shaft['path'][0])
        self.assertAlmostEqual(blade['length'] / (length + blade['length']), .22)
        self.assertEqual(blade['jag']['count'], 6)
        invalid = deepcopy(spec)
        next(p for p in invalid['pieces'] if p['id'] == 'breastplate')['offset_surface'] = .016
        with self.assertRaisesRegex(ValueError, 'offset must not exceed'):
            validate(invalid)

    def test_board_facing_normalizes_asset_and_rest_rig_without_moving_pose_paths(self):
        from spec.art_identity.maquettes.blender.facing import board_spec, axis_report
        spec = json.loads(R3.read_text())
        original = deepcopy(spec)
        working = board_spec(spec)
        self.assertEqual(spec, original)
        for b in spec['armature']['bones']:
            names = [b['head'], b['tail']]
            before = np.linalg.norm(np.subtract(*[spec['joints'][n] for n in names]))
            after = np.linalg.norm(np.subtract(*[working['joints'][n] for n in names]))
            self.assertAlmostEqual(before, after)
        forward = np.asarray(working['base']['matrix'])[:3, :3] @ [0, -1, 0]
        np.testing.assert_allclose(forward / np.linalg.norm(forward), [1, 0, 0], atol=1e-12)
        for name in ('cloak', 'spear_shaft', 'spear_blade'):
            a = next(p for p in spec['pieces'] if p['id'] == name)
            b = next(p for p in working['pieces'] if p['id'] == name)
            for key in ('pattern', 'path', 'rot'):
                if key in a:
                    self.assertEqual(a[key], b[key])
        import math
        for name in ('breastplate', 'chest_gem', 'face_plate'):
            p = next(p for p in working['pieces'] if p['id'] == name)
            rx, ry, rz = p['rot']
            self.assertEqual(ry, 0)
            forward = [math.sin(rz) * math.cos(rx), -math.cos(rz) * math.cos(rx), -math.sin(rx)]
            self.assertTrue(axis_report(working, forward)['passed'], name)
        self.assertTrue(axis_report(spec, [1, 0, 0])['passed'])
        self.assertFalse(axis_report(spec, [1, 1, 0])['passed'])
        self.assertFalse(axis_report(spec, [-1, 0, 0])['passed'])
        self.assertAlmostEqual(axis_report(spec, [1, 0, 0])['front_forward_screen'][1] /
                               axis_report(spec, [1, 0, 0])['front_forward_screen'][0], -.5)

    def test_shared_authoring_rotations_do_not_turn_other_attachments(self):
        from spec.art_identity.maquettes.blender.propose_lancer import propose
        from spec.art_identity.maquettes.blender.refine_lancer import refine
        from spec.art_identity.maquettes.blender.facing import board_spec
        spec = refine(propose())
        original = deepcopy(spec)
        working = board_spec(spec)
        self.assertEqual(spec, original)
        for name in ('vambrace_near', 'poleyn_far', 'sabaton_near'):
            self.assertEqual(next(p for p in working['pieces'] if p['id'] == name)['rot'],
                             next(p for p in spec['pieces'] if p['id'] == name)['rot'])

    def test_tabard_is_one_connected_pattern_with_four_lower_strips(self):
        spec = json.loads(R3.read_text())
        panel, = [p for p in spec['pieces'] if p.get('kind') == 'tabard']
        vertices, faces = pattern_mesh(panel['pattern'], panel['rag'])
        n = panel['pattern']['columns']
        splits = panel['pattern']['splits']
        self.assertEqual(len(splits['columns']), 3)
        self.assertEqual(len(panel['pattern']['pins']), n)
        # Entire garment is connected above the cuts; removing upper rows leaves
        # exactly four independently simulated strips, not four separate panels.
        def components(selected):
            adjacency = {}
            for face in selected:
                for a in face:
                    adjacency.setdefault(a, set()).update(face)
            count = 0
            while adjacency:
                pending = [next(iter(adjacency))]
                count += 1
                while pending:
                    pending.extend(adjacency.pop(pending.pop(), set()))
            return count
        self.assertEqual(components(faces), 1)
        self.assertEqual(components([f for f in faces if min(f) >= splits['from_row'] * n]), 4)
        self.assertTrue(all(next(p for p in spec['pieces'] if p['id'] == 'tasset_' + side)['contact_pieces'] == ['tabard_front'] for side in ('near', 'far')))
        invalid = deepcopy(panel['pattern'])
        invalid['splits']['from_row'] = 0
        with self.assertRaisesRegex(ValueError, 'strip cuts'):
            pattern_mesh(invalid, panel['rag'])

    def test_bridge_protocol_is_atomic_and_returns_director_log(self):
        from spec.art_identity.maquettes.blender.bridge_client import submit, wait
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'queue').mkdir()
            (root / 'done').mkdir()
            script = PROJECT / 'spec/art_identity/maquettes/blender/integration.py'
            identifier = submit(script, ['/private/tmp/labyrinth_codex/mq-03/test'], root=root)
            job = json.loads((root / 'queue' / (identifier + '.json')).read_text())
            self.assertEqual(job['script'], str(script))
            self.assertEqual(job['timeout_s'], 120)
            self.assertFalse(list((root / 'queue').glob('*.tmp')))
            (root / 'done' / (identifier + '.json')).write_text(json.dumps({'exit': 0, 'seconds': 2, 'log': ''}))
            (root / 'done' / (identifier + '.log')).write_text('BLENDER_NATIVE_INTEGRATION: PASS')
            result = wait(identifier, root=root)
            self.assertEqual(result['exit'], 0)
            self.assertIn('INTEGRATION: PASS', result['stdout'])

    def test_bridge_rejects_other_scripts_and_excessive_timeouts(self):
        from spec.art_identity.maquettes.blender.bridge_client import submit
        with self.assertRaisesRegex(ValueError, 'maquette Python'):
            submit(PROJECT / 'tools/maquette_fit.py', [])
        with self.assertRaisesRegex(ValueError, 'timeout'):
            submit(PROJECT / 'spec/art_identity/maquettes/blender/integration.py', [], timeout_s=1801)
        with self.assertRaisesRegex(ValueError, 'outside allowed roots'):
            submit(PROJECT / 'spec/art_identity/maquettes/blender/integration.py', ['/etc/passwd'])

    def test_valid_contract_and_unknown_labels(self):
        spec = fixture()
        spec['armature']['bones'][0]['parent'] = None
        validate(spec)
        spec['pieces'] = [{'id': 'x', 'type': 'gem', 'part': 'missing'}]
        with self.assertRaisesRegex(ValueError, 'Unknown piece'):
            validate(spec)

    def test_bone_cycles_and_zero_length_fail_before_launch(self):
        spec = fixture()
        spec['armature']['bones'][0]['parent'] = 'torso'
        with self.assertRaisesRegex(ValueError, 'cycle'):
            validate(spec)
        spec = fixture()
        spec['joints']['head'] = spec['joints']['torso'][:]
        with self.assertRaisesRegex(ValueError, 'Zero-length posed'):
            validate(spec)

    def test_mesh_hash_uses_coordinates_topology_and_ownership(self):
        vertices = [[0, 0, 0], [1, 0, 0], [0, 1, 0]]
        a = mesh_hash(vertices, [[0, 1, 2]], ['torso'])
        self.assertEqual(a, mesh_hash(deepcopy(vertices), [[0, 1, 2]], ['torso']))
        self.assertNotEqual(a, mesh_hash(vertices, [[0, 2, 1]], ['torso']))
        self.assertNotEqual(a, mesh_hash(vertices, [[0, 1, 2]], ['head']))

    def test_heat_weight_regions_cover_each_face_or_fail(self):
        owners = label_faces([], [[0, 1, 2]], [{'a': .8, 'b': .2}, {'a': .5}, {'b': .3}], {'a': 'torso', 'b': 'head'})
        self.assertEqual(owners, ['torso'])
        with self.assertRaisesRegex(ValueError, 'unlabelled'):
            label_faces([], [[0, 1, 2]], [{}, {}, {}], {'a': 'torso'})

    def test_collar_pattern_is_closed_and_symmetric_before_simulation(self):
        import math
        pattern = {'columns': 16, 'closed': True, 'pins': list(range(16)),
                   'rows': [{'centre': [0, 0, z], 'radii': [r, r], 'angles': [0, math.tau]}
                            for r, z in ((.1, 2), (.4, 1.7))]}
        vertices, faces = pattern_mesh(pattern, {'count': 0, 'depth': 0, 'seed': 1})
        self.assertIn((15, 0, 16, 31), faces)
        for x, y, z in vertices:
            self.assertTrue(any(abs(a + x) + abs(b - y) + abs(c - z) < 1e-10 for a, b, c in vertices))

    def test_seeded_rag_notches_only_change_the_hem_before_simulation(self):
        p = {'columns': 12, 'closed': False, 'pins': [0, 11],
             'rows': [{'a': [0, 0, 2], 'b': [1, 0, 2]}, {'a': [0, 0, 1], 'b': [1, 0, 1]}]}
        rag = {'count': 4, 'depth': .2, 'seed': 3}
        a, faces = pattern_mesh(p, rag)
        self.assertEqual((a, faces), pattern_mesh(p, rag))
        self.assertEqual(sum(v[2] > 1 for v in a[12:]), 4)
        self.assertTrue(all(v[2] == 2 for v in a[:12]))
        self.assertNotEqual(a, pattern_mesh(p, {**rag, 'seed': 8})[0])

    def test_command_disables_autorun_and_selects_cpu_backend(self):
        cmd = command('in.json', 'out', silhouettes=True, gallery=True)
        self.assertTrue(cmd[1].endswith('bridge_client.py'))
        self.assertEqual(cmd[cmd.index('--engine') + 1], 'cycles')
        self.assertIn('--gallery', cmd)

    def test_v2_cannot_silently_use_v1_rasteriser(self):
        with self.assertRaisesRegex(ValueError, 'Blender-rendered'):
            measure(fixture(), Image.new('RGBA', (100, 100)))
        with self.assertRaisesRegex(ValueError, 'Blender renderer'):
            fit_spec(fixture(), Image.new('RGBA', (100, 100)))

    def test_fit_never_changes_accessory_design_or_joint_xy(self):
        spec = fixture()
        spec['pieces'] = [{'id': 'gem', 'type': 'gem', 'part': 'torso', 'length': .2, 'width': .1,
                           'depth': .1, 'sides': 4, 'at': 'torso', 'offset': [0, 0, 0], 'rot': [0, 0, 0]}]
        original = deepcopy(spec)
        source = Image.new('RGBA', (100, 100))
        source.paste((255, 255, 255, 255), (30, 0, 70, 100))
        calls = []
        def renderer(candidate):
            calls.append(deepcopy(candidate))
            mask = np.zeros((100, 100), bool)
            mask[:, 40:60] = True
            return Raster(['torso'], np.where(mask, 0, -1), {'torso': mask},
                          {'torso': [50, 40], 'pelvis': [50, 80], 'head': [50, 0]})
        fitted = fit_spec(spec, source, renderer=renderer)
        self.assertEqual(spec, original)
        self.assertEqual(fitted['pieces'], original['pieces'])
        self.assertTrue(all(p[:2] == original['joints'][k][:2] for k, p in fitted['joints'].items()))
        self.assertTrue(calls)
        self.assertTrue(all(.6 <= x <= 1.6 for x in fitted['armature']['bones'][0]['scale']))

    def test_render_adapter_rejects_stale_spec_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, 'build_report.json').write_text(json.dumps({'spec_hash': 'old'}))
            with self.assertRaisesRegex(ValueError, 'different spec'):
                load_render(fixture(), tmp)

    def test_render_adapter_uses_solo_alpha_and_actual_joints(self):
        spec = fixture()
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / 'build_report.json').write_text(json.dumps({'spec_hash': digest(spec)}))
            (folder / 'joints_px.json').write_text(json.dumps({'front': spec['joints']}))
            image = Image.new('RGBA', (16, 16))
            image.paste((255, 255, 255, 255), (4, 2, 12, 15))
            for name in ('front_silhouette.png', 'front_solo_torso.png'):
                image.save(folder / name)
            from spec.art_identity.maquettes.blender.capture_manifest import write_manifest
            write_manifest(folder, digest(spec), 'full', ('front_silhouette.png', 'front_solo_torso.png'))
            raster = load_render(spec, folder)
            self.assertEqual(int(raster.silhouette.sum()), 8 * 13)
            np.testing.assert_array_equal(raster.silhouette, raster.masks['torso'])
            self.assertEqual(raster.joints, spec['joints'])

    @unittest.skipUnless(os.environ.get('LABYRINTH_BLENDER_PROOF') == '1',
                         'Set LABYRINTH_BLENDER_PROOF=1 to run native tests through the director bridge')
    def test_real_lancer_cloth_cache_replay_has_identical_raw_hashes(self):
        from spec.art_identity.maquettes.blender.bridge_client import run_job
        root = Path('/private/tmp/labyrinth_codex/mq-03/native_tests')
        root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=root) as tmp:
            result = run_job(PROJECT / 'spec/art_identity/maquettes/blender/cache_replay_probe.py', [str(R3), tmp])
            self.assertEqual(result['exit'], 0, result['stdout'])
            report = json.loads(Path(tmp, 'cache_replay_report.json').read_text())
            self.assertTrue(report['raw_hashes_identical'])

    @unittest.skipUnless(os.environ.get('LABYRINTH_BLENDER_PROOF') == '1',
                         'Set LABYRINTH_BLENDER_PROOF=1 to run native tests through the director bridge')
    def test_real_blender_build_and_geometry_gates(self):
        from spec.art_identity.maquettes.blender.bridge_client import run_job
        root = Path('/private/tmp/labyrinth_codex/mq-03/native_tests')
        root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=root) as tmp:
            result = run_job(PROJECT / 'spec/art_identity/maquettes/blender/integration.py', [tmp])
            self.assertEqual(result['exit'], 0, result['stdout'])


if __name__ == '__main__':
    unittest.main()
