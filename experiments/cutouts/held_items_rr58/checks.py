"""Focused rr-58 acceptance checks. Writes only unittest temporary directories."""
import unittest
import numpy as np
from PIL import Image
from config import ROOT, RIGS, assets, case, baseline_case, release, frame_count, read_json, digest
from partition import images_for, seer_rear, active
from recipes import released, masks_for
from proof import ownership
from maquette_motion.silhouette import components
import process_board_density as density


class HeldItemChecks(unittest.TestCase):
    def test_held_paint_motion_and_layouts_stay_protected(self):
        ownership()

    def test_palm_transfer_is_exact_and_reconnects_the_fist(self):
        root = assets('hoarfrost_seer') / 'humanoid_v2'
        layout = read_json(root / 'rear.json')
        original = images_for(root, layout)
        changed, mask = seer_rear(original)
        self.assertEqual(len(components(changed['hand_far'][..., 3] > 0, 8)[1]), 1)
        self.assertTrue(np.array_equal(changed['hand_far'][mask], original['staff'][mask]))
        self.assertFalse(changed['staff'][..., 3][mask].any())
        self.assertTrue(np.array_equal(changed['staff'][~mask], original['staff'][~mask]))
        self.assertTrue(np.array_equal(changed['hand_far'][~mask], original['hand_far'][~mask]))

    def test_release_is_scoped_to_the_original_death_boundary(self):
        for rig in RIGS:
            for view in ('front', 'rear'):
                layout = read_json(assets(rig) / f'humanoid_v2/{view}.json')
                for part in layout['parts']:
                    if not part.get('release_texture'): continue
                    boundary = release(rig, view, 'death')
                    self.assertEqual(active(part, 'death', boundary - .000001), part)
                    self.assertEqual(active(part, 'death', boundary)['file'], part['release_texture']['file'])
                    self.assertEqual(active(part, 'idle', 1.0), part)
                    self.assertEqual(active(part, 'move', 1.0), part)
        # A released chain/fist gap is free space; adjacent anatomical joints
        # must still be checked. Exercise the inherited release boundary policy.
        from cpu import boundary_ownership
        from humanoid_cutout.cpu_pose import CpuPose
        root = baseline_case('chainbound_gaoler')
        for view in ('front', 'rear'):
            model = CpuPose(root, read_json(root / f'layouts/{view}.json'))
            original = model.layout['parts'][0]['proof_ownership']
            boundary = release('chainbound_gaoler', view, 'death')
            held = boundary_ownership(model, {'clip': 'death', 'phase': boundary - .000001})
            dropped = boundary_ownership(model, {'clip': 'death', 'phase': boundary})
            self.assertEqual(held, original)
            grip = frozenset(('chain', 'hand_far'))
            expected = [p for p in original['joint_pairs'] if frozenset(p) != grip]
            self.assertLess(len(expected), len(original['joint_pairs']))
            self.assertEqual(dropped, dict(original, joint_pairs=expected))
            self.assertEqual(boundary_ownership(model, {'clip': 'idle', 'phase': 1.0}), original)

    def test_director_requests_bind_actual_native_masks(self):
        names = []
        for rig in RIGS:
            folder = case(rig) / 'underlay_requests'
            for row in read_json(folder / 'index.json')['regions']:
                mask = np.asarray(Image.open(folder / row['mask']).convert('L')) > 0
                self.assertEqual(mask.shape, (255, 255))
                self.assertEqual(int(mask.sum()), row['uncovered_pixels'])
                self.assertEqual(digest(folder / row['mask']), row['mask_sha256'])
                self.assertEqual(row['status'], 'filled')
                self.assertTrue(row['fill']['mask_complete'])
                if rig == 'chainbound_gaoler' and row['view'] == 'rear':
                    self.assertEqual(row['bounds'], [158, 160, 181, 166])
                    self.assertEqual(list(Image.open(folder / row['mask']).getbbox()), row['bounds'])
                    self.assertEqual(row['fill']['copied_pixels'], 44)
                    self.assertEqual(row['fill']['source_region'], [161, 177, 178, 181])
                names.append((rig, row['view'], row['region']))
        self.assertEqual(len(names), 3)

    def test_density_reproduces_release_texels(self):
        registry = density.load_registry(); manifest = read_json(density.MANIFEST)
        for rig in RIGS:
            entry = next(e for e in registry['entries'] if e['id'] == rig + '_cutout')
            for path in entry['paths']:
                if 'released' not in path: continue
                actual, record = density.derive(entry, path)
                self.assertEqual(density.pixel_digest(actual), density.pixel_digest(Image.open(ROOT / path)))
                self.assertEqual(record, manifest[path])

    def test_source_variants_and_check_masks_match_existing_paint(self):
        for rig in RIGS:
            root = baseline_case(rig)
            for view in ('front', 'rear'):
                layout = read_json(root / f'layouts/{view}.json')
                changed, classifications, _ = released(rig, view, root, layout)
                production = read_json(assets(rig) / f'humanoid_v2/{view}.json')
                for name, full in changed.items():
                    part = next(p for p in production['parts'] if p['name'] == name)
                    a, b, c, d = part['release_texture']['bbox']
                    path = case(rig) / f'pieces/{view}/{name}_released.png'
                    self.assertTrue(np.array_equal(np.asarray(Image.open(path).convert('RGBA')), full[b:d, a:c]))
                    mask = np.asarray(Image.open(case(rig) / f'checks/{view}/{name}_released_checks.png').convert('RGBA'))
                    self.assertTrue(np.array_equal(mask, classifications[name][b:d, a:c]))

    def test_item_donors_are_exact_and_mask_limited(self):
        for rig in RIGS:
            for record in read_json(case(rig) / 'ownership.json')['donor_fills']:
                view = record['view']; root = (assets(rig) / 'humanoid_v2' if record['paint_scope'] == 'production' else baseline_case(rig))
                layout = read_json(root / (view + '.json' if record['paint_scope'] == 'production' else f'layouts/{view}.json'))
                images = images_for(root, layout); item = record['source_part']; original = images[item]
                mask = np.asarray(Image.open(case(rig) / f'underlay_requests/{view}_{record["region"]}.png').convert('L')) > 0
                changed, _, _ = released(rig, view, root, layout)
                for (x, y, u, v), rgba in zip(record['texels'], record['rgba']):
                    self.assertTrue(mask[y, x]); self.assertTrue(original[v, u, 3])
                    self.assertEqual(original[v, u].tolist(), rgba)
                    self.assertEqual(changed[item][y, x].tolist(), rgba)
                if item == 'chain':
                    self.assertTrue(np.array_equal(original[~mask], changed[item][~mask]))
                    self.assertLessEqual(max(record['endpoint_distance_px']), 1)
                else:
                    checks = masks_for(rig, view)[item]
                    outline_edges = []
                    for row in record['rows']:
                        x0, x1 = row['source_x']; v = row['source_y']
                        self.assertTrue(checks[v, x0, 2] and checks[v, x1-1, 2])
                        outline_edges.append((x0 + row['translation_x'], x1 - 1 + row['translation_x']))
                    self.assertTrue((np.abs(np.diff(outline_edges, axis=0)) <= 1).all())

    def test_frame_inventory_uses_godot_rounding(self):
        self.assertEqual(frame_count({'seconds': .175}), 11)
        self.assertEqual(frame_count({'seconds': .84}), 50)


if __name__ == '__main__': unittest.main(verbosity=2)
