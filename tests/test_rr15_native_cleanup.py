"""Native failure fixtures and CPU regressions for Thrall source cleanup."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/arc_thrall')]
from cutout_pipeline.cases import read_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.silhouette_gates import detached_metrics, joint_holes, JOINT_NEIGHBOURHOOD_PX
from humanoid_cutout.underlays import native_order
from maquette_motion.pixels import render, unpack, changed, rest_identity, native_frame_matches
from maquette_motion.native_ties import select
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components, dilate
from rr15_cpu_proof import CASE, frame_state
from tests.gait01.preservation import assert_preserved

FIXTURES = PROJECT / 'tests/rr11/rr15'
DETACHED_POSES = [('front', 'jab', 5), ('rear', 'tether', 15)]
SEAM_POSES = [('front', 'jab', 5), ('rear', 'move', 6)]
GEOMETRY_FIELDS = ('bbox', 'vertices', 'uvs', 'triangles', 'weights', 'weight_bounds')
INVALID_TIE_COLOR = [255, 0, 255, 255]


class NativeCleanupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.models = {view: CpuPose(CASE, read_json(CASE / f'layouts/{view}.json')) for view in ('front', 'rear')}
        cls.poses = {(r['view'], r['clip'], r['frame']): r for r in read_json(CASE / 'proof/samples.json')['samples']
                     if r['kind'] == 'presented'}

    def test_front_idle6_native_overlap_and_distinct_underlay_priority(self):
        # Captured native pixels, not a self-generated expected composite.
        native = np.asarray(Image.open(FIXTURES / 'front_idle6_native.png').convert('RGBA'))
        rows = read_json(FIXTURES / 'overlap_before.json')
        def composite(order):
            result = Image.new('RGBA', (native.shape[1], native.shape[0]))
            for row in order:
                result.alpha_composite(Image.open(FIXTURES / f'front_idle6_{row["name"]}.png').convert('RGBA'))
            return result
        wrong = composite(sorted(rows, key=lambda r: r['z_index']))
        self.assertEqual(int(changed(native, np.asarray(wrong)).sum()), 7)
        depths = {p['name']: p['z_index'] for p in self.models['front'].layout['parts']}
        correct = composite(sorted(rows, key=lambda r: depths[r['name']]))
        self.assertEqual(int(changed(native, np.asarray(correct)).sum()), 0)
        for model in self.models.values():
            parts = {p['name']: p for p in model.layout['parts']}
            depths = [parts[n]['z_index'] for n in native_order(model.layout) if parts[n].get('hidden_material')]
            self.assertEqual(depths, sorted(set(depths)))
            self.assertLess(max(depths), min(p['z_index'] for p in parts.values() if not p.get('hidden_material')))
            self.assertLess(parts['hidden_upper_near']['z_index'], parts['hidden_torso']['z_index'])

    def test_detached_source_edges_attach_to_their_actual_pieces(self):
        for key in DETACHED_POSES:
            view, clip, frame = key
            before = np.asarray(Image.open(FIXTURES / f'{view}_{clip}{frame}_native.png').convert('RGBA'))
            self.assertGreater(detached_metrics(before)['stray_components'], 0)
            layers = frame_state(self.models[view], self.poses[key])[0]
            composite = Image.new('RGBA', (512, 512))
            for part, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
                composite.alpha_composite(Image.fromarray(image))
            self.assertEqual(detached_metrics(np.asarray(composite))['stray_components'], 0)

    def test_every_visible_source_texel_retains_its_exact_color_and_correct_owner(self):
        transfers = read_json(CASE / 'edge_transfers.json')
        for view, model in self.models.items():
            baseline = CASE / (view + '_baseline')
            old = read_json(baseline / f'layouts/{view}.json')
            expected = {name: np.zeros((255, 255, 4), dtype=np.uint8) for name in model.layout['source_labels']}
            for part in old['parts']:
                name = next(n for n, labels in model.layout['source_labels'].items() if part['logical_part'] in labels)
                image = source_pixels(baseline, part)
                mask = image[..., 3] > 0
                expected[name][mask] = image[mask]
            for row in transfers[view]:
                source = expected[row['source']]
                labels, _ = components(source[..., 3] > 0, 8)
                x, y = row['seed']
                mask = labels == labels[y, x]
                self.assertEqual(int(mask.sum()), row['pixels'])
                expected[row['owner']][mask] = source[mask]
                source[mask] = 0
            for part in model.layout['parts']:
                if part.get('hidden_material'):
                    continue
                actual = source_pixels(CASE, part)
                record = model.layout['proof_layers'][part['name']]
                checks = np.zeros_like(actual)
                mask = model.image(record['mask'])
                x, y = record['mask_offset']
                checks[y:y + mask.shape[0], x:x + mask.shape[1]] = mask
                actual[checks[..., 1] > 0] = 0
                self.assertTrue(np.array_equal(actual, expected[part['name']]), (view, part['name']))

    def test_joint_continuations_close_holes_and_removal_reopens_them(self):
        for key in SEAM_POSES:
            view = key[0]
            model, pose = self.models[view], self.poses[key]
            if key == ('rear', 'move', 6):
                # The retained GPU defect belongs to the old walk pose.
                pose = read_json(FIXTURES / 'legacy_rear_move6_pose.json')
            # Pin the actual retained GPU defect, rather than unrelated CPU
            # raster-boundary predictions elsewhere in the same pose.
            target = np.asarray(Image.open(FIXTURES / f'{view}_{key[1]}{key[2]}_native_joint_hole.png')) > 0
            def rejected(state):
                _, owners, seam, refs, _ = state
                seam = seam & dilate(target, JOINT_NEIGHBOURHOOD_PX)
                return joint_holes(owners > 0, seam, owners, refs)
            self.assertEqual(rejected(frame_state(model, pose)), [], key)
            overrides = {p['name']: model.image(p['file']).copy() for p in model.layout['parts']}
            for part in model.layout['parts']:
                # Remove added continuation alpha, preserving current original
                # paint, including the corrected tube/claw edge ownership.
                path = FIXTURES / f'{view}_{part["name"]}_before_alpha.png'
                if part.get('joint_extension'):
                    mask = np.zeros((255, 255), dtype=bool)
                else:
                    mask = np.asarray(Image.open(path)) > 0
                x, y, right, bottom = part['bbox']
                before = mask[y:bottom, x:right].copy()
                checks = model.image(model.layout['proof_layers'][part['name']]['mask'])
                before |= (checks[..., 3] > 0) & (checks[..., 1] == 0)
                overrides[part['name']][~before] = 0
            self.assertTrue(rejected(frame_state(model, pose, overrides)), key)

    def test_hidden_tube_native_ties_are_exact_real_source_candidates(self):
        source = Image.open(FIXTURES / 'rear_hidden_tube_before.png').convert('RGBA')
        for row in read_json(FIXTURES / 'rigid_before.json'):
            key = f'rear_{row["clip"]}{row["frame"]}_hidden_tube_native.png'
            actual = np.asarray(Image.open(FIXTURES / key).convert('RGBA'))
            samples = render(source, unpack(row['transform']), with_ties=True)
            self.assertEqual(int(changed(actual, samples.default).sum()), 4)
            matched, invalid = select(actual, samples)
            self.assertFalse(invalid.any())
            self.assertFalse(changed(actual, matched).any())
            self.assertTrue(native_frame_matches(actual, samples.default, samples))
            broken = actual.copy()
            broken[samples.ties] = INVALID_TIE_COLOR
            self.assertFalse(native_frame_matches(broken, samples.default, samples))

    def test_only_the_two_native_hip_speck_texels_are_removed_from_the_torso_seed(self):
        model = self.models['rear']
        parts = {p['name']: p for p in model.layout['parts']}
        def alpha(name):
            part = parts[name]
            result = np.zeros((255, 255), dtype=bool)
            x, y, right, bottom = part['bbox']
            result[y:bottom, x:right] = model.image(part['file'])[..., 3] > 0
            return result
        before = np.asarray(Image.open(FIXTURES / 'rear_hidden_torso_before_source.png').convert('RGBA'))[..., 3] > 0
        current = alpha('hidden_torso')
        ys, xs = np.nonzero(before & ~current)
        self.assertEqual(set(zip(xs.tolist(), ys.tolist())), {(100, 138), (104, 142)})
        # Other cleanup may trim only material added by rr-15. Opening a
        # continuation loop must never erase an original painted/hidden edge.
        for view, pieces in read_json(CASE / 'continuation_alpha_cleanup.json').items():
            for name, points in pieces.items():
                original = np.zeros((255, 255), dtype=bool)
                for part_name in (name, 'hidden_' + name):
                    path = FIXTURES / f'{view}_{part_name}_before_alpha.png'
                    if path.exists():
                        original |= np.asarray(Image.open(path)) > 0
                for x, y in points:
                    if view == 'rear' and name == 'torso' and (x, y) in {(100, 138), (104, 142)}:
                        continue
                    self.assertFalse(original[y, x], (view, name, x, y))

    def test_paint_motion_rest_and_visible_mesh_fields_are_unchanged(self):
        self.assertTrue(rest_identity(CASE)['ok'])
        for path, expected in read_json(FIXTURES / 'protected.json').items():
            assert_preserved(self, PROJECT, path, expected)
        geometry = read_json(FIXTURES / 'geometry_before.json')
        for view, model in self.models.items():
            for mesh in model.layout['joint_meshes']:
                if view + '/' + mesh['name'] not in geometry:
                    self.assertTrue(mesh.get('hidden_material'))
                    continue
                fields = {k: mesh[k] for k in GEOMETRY_FIELDS if k in mesh}
                actual = hashlib.sha256(json.dumps(fields, sort_keys=True).encode()).hexdigest()
                self.assertEqual(actual, geometry[view + '/' + mesh['name']])


if __name__ == '__main__':
    unittest.main()
