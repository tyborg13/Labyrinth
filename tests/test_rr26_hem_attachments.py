"""Neighbour inheritance, original-paint coverage and hem-fragment mutations."""
from copy import deepcopy
from pathlib import Path
import sys
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import read_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import structure_errors, source_errors
from humanoid_cutout.rest_space import DetachedSource
from humanoid_cutout.texel_attachments import attach, base_mesh, barycentric

CASE = ROOT / 'experiments/cutouts/hoarfrost_seer/rr10'
TARGET_FRAMES = {'front': (11, 12, 15), 'rear': (10, 13)}
MUTATION_WEIGHT_DELTA = .01


class HemAttachmentTests(unittest.TestCase):
    def setUp(self):
        self.layouts = {view: read_json(CASE / f'layouts/{view}.json') for view in TARGET_FRAMES}
        self.recipe = read_json(CASE / 'anatomy.json')['meshes']['robe']
        self.build = read_json(CASE / 'proof/build.json')

    def test_each_tip_copies_its_painted_eight_connected_neighbour_exactly(self):
        for layout in self.layouts.values():
            mesh = next(m for m in layout['joint_meshes'] if m['name'] == 'robe')
            base = base_mesh(mesh, layout, self.recipe)
            parents = {tuple(row['texel']): tuple(row['neighbour']) for row in mesh['texel_attachments']}
            start = len(base['vertices'])
            assigned = {}
            for index, point in enumerate(sorted(parents, key=lambda p: (p[1], p[0]))):
                parent = parents[point]
                self.assertEqual(max(abs(a - b) for a, b in zip(point, parent)), 1)
                root = parent
                while root in parents: root = parents[root]
                indices, bary = barycentric(base, (root[0] + .5, root[1] + .5))
                expected = {bone: float(bary @ np.asarray(values)[indices]) for bone, values in base['weights'].items()}
                actual = {bone: values[start + 4 * index] for bone, values in mesh['weights'].items()}
                self.assertEqual(actual, expected)
                assigned[point] = actual
                for values in mesh['weights'].values():
                    self.assertEqual(values[start + 4 * index:start + 4 * index + 4], [values[start + 4 * index]] * 4)
            for point, parent in parents.items():
                if parent in assigned: self.assertEqual(assigned[point], assigned[parent])

    def test_original_vertices_and_weights_remain_exact(self):
        for layout in self.layouts.values():
            mesh = next(m for m in layout['joint_meshes'] if m['name'] == 'robe')
            base = base_mesh(mesh, layout, self.recipe)
            count = len(base['vertices'])
            self.assertEqual(mesh['vertices'][:count], base['vertices'])
            self.assertEqual(mesh['uvs'][:count], base['uvs'])
            for bone in base['weights']: self.assertEqual(mesh['weights'][bone][:count], base['weights'][bone])
            self.assertEqual(structure_errors(layout, self.build), [])
            self.assertEqual(source_errors(CASE, layout, self.build), [])

    def test_neutral_pose_raster_preserves_every_painted_texel(self):
        for layout in self.layouts.values():
            old = deepcopy(layout)
            for index, mesh in enumerate(old['joint_meshes']):
                if mesh['name'] == 'robe': old['joint_meshes'][index] = base_mesh(mesh, old, self.recipe)
            pose = {'clip': 'idle', 'bones': {name: {'global': [1, 0, 0, 1, *joint['position']]}
                                             for name, joint in layout['joints'].items()}}
            before = CpuPose(CASE, old).layers(pose)[0]
            after = CpuPose(CASE, layout).layers(pose)[0]
            for (_, original, _), (_, current, _) in zip(before, after):
                np.testing.assert_array_equal(current, original)

    def test_all_five_failures_reopen_when_attachments_are_removed(self):
        samples = read_json(CASE / 'proof/samples.json')['samples']
        for view, frames in TARGET_FRAMES.items():
            layout = self.layouts[view]
            old = deepcopy(layout)
            for index, mesh in enumerate(old['joint_meshes']):
                if mesh['name'] == 'robe': old['joint_meshes'][index] = base_mesh(mesh, old, self.recipe)
            current_model, old_model = CpuPose(CASE, layout), CpuPose(CASE, old)
            source = DetachedSource(CASE, layout)
            for frame in frames:
                pose = next(p for p in samples if p['kind'] == 'presented' and
                            (p['view'], p['clip'], p['frame']) == (view, 'move', frame))
                transforms = {k: v['transform'] for k, v in pose['parts'].items()}
                self.assertEqual(source.report(current_model.layers(pose)[0], transforms)['metrics']['stray_components'], 0)
                self.assertGreater(source.report(old_model.layers(pose)[0], transforms)['metrics']['stray_components'], 0)

    def test_non_neighbour_and_cyclic_links_are_rejected(self):
        layout = self.layouts['front']
        mesh = next(m for m in layout['joint_meshes'] if m['name'] == 'robe')
        base = base_mesh(mesh, layout, self.recipe)
        rows = deepcopy(mesh['texel_attachments'])
        rows[0]['neighbour'] = [rows[0]['texel'][0] + 2, rows[0]['texel'][1]]
        with self.assertRaises(ValueError): attach(base, rows)
        rows = [{'texel': [152, 234], 'neighbour': [152, 235]},
                {'texel': [152, 235], 'neighbour': [152, 234]}]
        with self.assertRaises(ValueError): attach(base, rows)

    def test_air_donors_missing_paint_and_arbitrary_weights_are_rejected(self):
        for mutation in ('air', 'missing', 'weight'):
            layout = deepcopy(self.layouts['front'])
            mesh = next(m for m in layout['joint_meshes'] if m['name'] == 'robe')
            base = base_mesh(mesh, layout, self.recipe)
            if mutation == 'weight':
                mesh['weights']['pelvis'][-1] += MUTATION_WEIGHT_DELTA
                self.assertTrue(structure_errors(layout, self.build))
                continue
            rows = deepcopy(mesh['texel_attachments'])
            if mutation == 'air': rows[0]['neighbour'] = [151, 234]
            else: rows.pop()
            mesh.clear(); mesh.update(attach(base, rows))
            self.assertTrue(source_errors(CASE, layout, self.build))


if __name__ == '__main__': unittest.main()
