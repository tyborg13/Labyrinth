"""Shared mesh, camera, silhouette and fit contracts (no Blender required)."""
from copy import deepcopy
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.geometry import (Mesh, build_meshes, deform_width, grid_mesh,
    shape_meshes, sphere, solidify)
from spec.art_identity.maquettes.fitting import (FIT_DEFAULTS, fit_spec, frame, keyed_mask,
    measure, normalise_points, width_bands)
from spec.art_identity.maquettes.raster import project, rasterise
from spec.art_identity.maquettes.remesh import voxel_union
from spec.art_identity.maquettes.shrike_spec import legacy_shrike
from spec.art_identity.maquettes.compatibility import compare_renders, iou


def spec_for(shapes):
    return {'ortho_scale': 4, 'target': [0, 0, 1], 'joints': {'head': [0, 0, 2], 'knee': [0, 0, 0.7]},
            'labels': {s['part']: [1, 0, 0] for s in shapes}, 'shapes': shapes}


def example():
    return spec_for([{'type': 'ellipsoid', 'part': 'head', 'c': [0, 0, 1.9], 's': [0.2, 0.2, 0.3]},
                     {'type': 'capsule', 'part': 'body', 'a': [0, 0, 0.15], 'b': [0, 0, 1.5], 'r1': 0.15, 'r2': 0.3}])


def annotated(spec):
    """Synthetic approved source: exact raster with explicit figure frame."""
    raster = rasterise(spec)
    definition = frame(raster.silhouette, raster.masks['head'])
    spec['fit'] = {'source_frame': definition, 'landmarks': {'knee': {'y': float(normalise_points(raster.joints['knee'], definition)[1]), 'joint': 'knee'}}}
    return Image.fromarray(raster.rgba(spec))


class GeometryTests(unittest.TestCase):
    def assert_mesh(self, mesh):
        self.assertTrue(np.isfinite(mesh.vertices).all())
        self.assertGreater(len(mesh.faces), 0)
        triangles = mesh.vertices[mesh.faces]
        self.assertTrue(np.all(np.linalg.norm(np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0]), axis=1) > 1e-14))

    def test_legacy_specs_build_without_mutation(self):
        for path in (PROJECT / 'spec/art_identity/maquettes').glob('*/spec.json'):
            spec = json.loads(path.read_text()); original = deepcopy(spec)
            with self.subTest(spec=path.parent.name):
                meshes = build_meshes(spec)
                self.assertEqual(set(meshes), set(spec['labels']))
                for mesh in meshes.values():
                    self.assert_mesh(mesh)
                self.assertEqual(spec, original)

    def test_capsule_bounds_retain_endpoint_spheres(self):
        mesh = build_meshes(spec_for([{'type': 'capsule', 'part': 'p', 'a': [0, 0, 0], 'b': [0, 0, 1], 'r1': .2, 'r2': .1}]))['p']
        np.testing.assert_allclose(mesh.vertices.min(0), [-.2, -.2, -.2])
        np.testing.assert_allclose(mesh.vertices.max(0), [.2, .2, 1.1])

    def test_limb_profile_midpoint_is_not_an_endpoint_sphere(self):
        mesh = build_meshes(spec_for([{'type': 'limb', 'part': 'p', 'a': [0, 0, 0], 'b': [0, 0, 1], 'radii': [.1, .3, .08], 'mid_at': .4}]))['p']
        self.assert_mesh(mesh)
        ring = mesh.vertices[np.isclose(mesh.vertices[:, 2], .4)]
        np.testing.assert_allclose(np.linalg.norm(ring[:, :2], axis=1), .3)
        with self.assertRaises(ValueError):
            shape_meshes({'type': 'limb', 'part': 'p', 'a': [0, 0, 0], 'b': [0, 0, 1], 'radii': [.1, .2, .1], 'mid_at': 1}, {})

    def test_torso_has_waist_and_lean(self):
        shape = {'type': 'torso', 'part': 'p', 'c': [0, 0, 0], 'sections': [
            {'z': 0, 'width': .7, 'depth': .5, 'round': 2}, {'z': .5, 'width': .4, 'depth': .3, 'round': 3},
            {'z': 1, 'width': .8, 'depth': .5, 'round': 2}], 'lean': [.1, 0]}
        mesh = build_meshes(spec_for([shape]))['p']
        self.assert_mesh(mesh)
        waist = mesh.vertices[np.isclose(mesh.vertices[:, 2], .5)]
        self.assertAlmostEqual(np.ptp(waist[:, 1]), .4)
        top = mesh.vertices[np.isclose(mesh.vertices[:, 2], 1)]
        self.assertAlmostEqual(top[:, 0].mean(), .1)

    def test_shell_is_open_cap_with_thickness(self):
        shape = {'type': 'shell', 'part': 'p', 'c': [0, 0, 0], 's': [1, 1, 1],
                 'cut': {'polar': [0, math.pi / 2]}, 'thick': .05}
        mesh = build_meshes(spec_for([shape]))['p']
        self.assert_mesh(mesh)
        self.assertGreaterEqual(mesh.vertices[:, 2].min(), -.01)
        edges, counts = np.unique(np.sort(np.concatenate([mesh.faces[:, [0, 1]], mesh.faces[:, [1, 2]], mesh.faces[:, [2, 0]]]), axis=1), axis=0, return_counts=True)
        self.assertTrue(np.all(counts == 2), 'thick shell must close its cut rim')

    def test_concave_plate_does_not_fill_the_notch(self):
        shape = {'type': 'plate', 'part': 'p', 'pts': [[0, 0, 0], [1, 0, 0], [1, 1, 0], [.5, .3, 0], [0, 1, 0]], 'thick': .1}
        mesh = build_meshes(spec_for([shape]))['p']
        self.assert_mesh(mesh)
        triangles = mesh.vertices[mesh.faces[:3]]
        area = sum(np.linalg.norm(np.cross(t[1] - t[0], t[2] - t[0])) / 2 for t in triangles)
        self.assertAlmostEqual(area, .65)

    def test_cloak_is_deterministic_anchored_and_notched(self):
        shape = {'type': 'cloak', 'part': 'p', 'anchors': [[0, -.2, 1.8], [0, .2, 1.8]], 'length': 1.5,
                 'hem_width': 1.2, 'flare': .1, 'wrap': math.pi, 'folds': {'count': 4, 'depth': .03},
                 'rag': {'count': 5, 'depth': .12, 'seed': 7}, 'thick': .02}
        a = build_meshes(spec_for([shape]))['p']; b = build_meshes(spec_for([shape]))['p']
        np.testing.assert_array_equal(a.vertices, b.vertices)
        self.assert_mesh(a)
        self.assertGreater(np.ptp(a.vertices[:, 1]), 1.1)
        for anchor in shape['anchors']:
            self.assertLess(np.linalg.norm(a.vertices - anchor, axis=1).min(), 1e-10)

    def test_voxel_union_is_welded_closed_and_repeatable(self):
        shapes = [{'type': 'ellipsoid', 'part': 'p', 'c': [x, 0, 0], 's': [.3, .3, .3]} for x in (-.15, .15)]
        spec = spec_for(shapes); spec['part_options'] = {'p': {'smooth': True, 'voxel': .08}}
        a = build_meshes(spec)['p']; b = build_meshes(spec)['p']
        self.assert_mesh(a)
        np.testing.assert_array_equal(a.vertices, b.vertices)
        self.assertEqual(len(a.vertices), len(np.unique(a.vertices, axis=0)))
        edges = np.sort(np.concatenate([a.faces[:, [0, 1]], a.faces[:, [1, 2]], a.faces[:, [2, 0]]]), axis=1)
        _, counts = np.unique(edges, axis=0, return_counts=True)
        self.assertTrue(np.all(counts == 2))
        with self.assertRaises(ValueError):
            voxel_union([sphere()], 0)

    def test_unknown_primitive_is_an_error(self):
        with self.assertRaisesRegex(ValueError, 'Unknown primitive'):
            build_meshes(spec_for([{'type': 'typo', 'part': 'p'}]))


class RasterTests(unittest.TestCase):
    def test_committed_solo_silhouettes_clear_back_compat_gate(self):
        cases = [(json.loads((PROJECT / 'spec/art_identity/maquettes/chainbound_gaoler/spec.json').read_text()),
                  PROJECT / 'spec/art_identity/jobs/chainbound_gaoler/mq3_maquette_renders'),
                 (legacy_shrike(), PROJECT / 'experiments/cutouts/gust_shrike/mq2/source/maquette')]
        for spec, folder in cases:
            for view in ('front', 'rear'):
                raster = rasterise(spec, view)
                for part in spec['labels']:
                    with self.subTest(spec=folder, view=view, part=part):
                        expected = np.asarray(Image.open(folder / f'{view}_solo_{part}.png').convert('RGBA'))[..., 3] >= 128
                        self.assertGreaterEqual(iou(expected, raster.masks[part]), .98)

    def test_joint_projection_matches_committed_blender_for_both_views(self):
        cases = [(json.loads((PROJECT / 'spec/art_identity/maquettes/chainbound_gaoler/spec.json').read_text()),
                  PROJECT / 'spec/art_identity/jobs/chainbound_gaoler/mq3_maquette_renders/joints_px.json'),
                 (legacy_shrike(), PROJECT / 'experiments/cutouts/gust_shrike/mq2/source/maquette/joints_px.json')]
        for spec, path in cases:
            for view, joints in json.loads(path.read_text()).items():
                for name, expected in joints.items():
                    np.testing.assert_allclose(project(spec, spec['joints'][name], view)[:2], expected, atol=.02)

    def test_depth_ownership_and_solos(self):
        # Camera-toward displacement changes depth without changing projection.
        toward = np.array([math.sqrt(3 / 8), math.sqrt(3 / 8), .5])
        shape = {'type': 'ellipsoid', 'part': 'back', 'c': [0, 0, 1], 's': [.3, .3, .3]}
        front = {**shape, 'part': 'front', 'c': (np.array(shape['c']) + toward).tolist()}
        raster = rasterise(spec_for([shape, front]), size=128)
        self.assertFalse(np.any(raster.owners == 0))
        self.assertTrue(np.any(raster.owners == 1))
        np.testing.assert_array_equal(raster.masks['back'], raster.masks['front'])

    def test_clipping_handles_off_canvas_and_degenerate_triangles(self):
        spec = spec_for([{'type': 'mesh', 'part': 'p', 'vertices': [[-10, 0, 1], [10, 0, 1], [0, 0, 10], [0, 0, 1]], 'faces': [[0, 1, 2], [3, 3, 3]]}])
        self.assertTrue(rasterise(spec, size=64).silhouette.any())


class FitTests(unittest.TestCase):
    def test_band_fit_improves_a_wider_source(self):
        spec = example(); source = annotated(spec)
        scale = 1.25
        centre = spec['fit']['source_frame']['ground_x']
        source = source.transform(source.size, Image.Transform.AFFINE,
                                  (1 / scale, 0, centre * (1 - 1 / scale), 0, 1, 0), resample=Image.Resampling.NEAREST)
        before = measure(spec, source)[0]
        result = fit_spec(spec, source)
        after = measure(result, source)[0]
        self.assertGreater(after['iou'], before['iou'])
        self.assertLess(after['median_band_error'], before['median_band_error'])

    def test_director_render_comparison_requires_every_solo(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); baseline = root / 'old'; candidate = root / 'new'
            spec = example(); raster = rasterise(spec)
            for out in (baseline, candidate):
                out.mkdir()
                (out / 'joints_px.json').write_text(json.dumps({'front': raster.joints, 'rear': raster.joints}))
                for view in ('front', 'rear'):
                    for part, mask in raster.masks.items():
                        rgba = np.zeros((*mask.shape, 4), dtype=np.uint8); rgba[mask] = 255
                        Image.fromarray(rgba).save(out / f'{view}_solo_{part}.png')
            report = compare_renders(spec, baseline, candidate)
            self.assertEqual(report['front']['minimum_part_silhouette_iou'], 1)
            (candidate / 'rear_solo_head.png').unlink()
            with self.assertRaisesRegex(ValueError, 'Missing solo proof'):
                compare_renders(spec, baseline, candidate)

    def test_green_key_and_transparent_masks(self):
        pixels = np.array([[[0, 255, 0, 255], [10, 10, 10, 255], [0, 0, 0, 0]]], dtype=np.uint8)
        self.assertEqual(keyed_mask(Image.fromarray(pixels)).tolist(), [[False, True, False]])

    def test_exact_source_passes_all_metrics(self):
        spec = example(); source = annotated(spec)
        report, overlay = measure(spec, source)
        self.assertEqual(report['iou'], 1)
        self.assertEqual(report['max_band_error'], 0)
        self.assertTrue(report['passed'])
        self.assertEqual(len(report['bands']), 24)
        self.assertGreater(overlay.width, source.width // 2)

    def test_missing_annotations_and_design_todos_never_pass(self):
        spec = example(); source = annotated(spec)
        spec['TODO_DESIGN_pose'] = 'pending'
        self.assertFalse(measure(spec, source)[0]['passed'])
        with self.assertRaisesRegex(ValueError, 'resolved design'):
            fit_spec(spec, source)
        del spec['TODO_DESIGN_pose']; del spec['fit']
        self.assertFalse(measure(spec, source)[0]['checks']['design_complete'])

    def test_landmark_fit_is_deterministic_monotonic_and_preserves_types(self):
        spec = example(); source = annotated(spec)
        spec['fit']['landmarks']['knee']['y'] -= .04
        original = deepcopy(spec)
        a = fit_spec(spec, source); b = fit_spec(spec, source)
        self.assertEqual(a, b)
        self.assertEqual(spec, original)
        self.assertEqual([s['type'] for s in a['shapes']], [s['type'] for s in spec['shapes']])
        self.assertLess(measure(a, source)[0]['landmarks']['knee']['absolute_error'], .003)
        ratios = a['fit_width_profile']['ratios']
        self.assertGreaterEqual(min(ratios), .6); self.assertLessEqual(max(ratios), 1.6)

    def test_width_map_moves_mesh_and_joint_in_the_same_camera_plane(self):
        spec = example(); source = annotated(spec)
        spec['fit_width_profile'] = {'ratios': [1.5] * 24, 'frame': spec['fit']['source_frame'], 'size': 1024}
        p = np.array([.2, .4, 1.])
        before = project(spec, p); after = project(spec, deform_width(spec, p))
        self.assertAlmostEqual(before[1], after[1]); self.assertAlmostEqual(before[2], after[2])
        centre = spec['fit']['source_frame']['ground_x']
        self.assertAlmostEqual(after[0] - centre, (before[0] - centre) * 1.5)

    def test_cli_never_overwrites_input(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); spec = example(); source = annotated(spec)
            source.save(root / 'source.png'); path = root / 'spec.json'; path.write_text(json.dumps(spec))
            before = path.read_bytes()
            run = subprocess.run([sys.executable, str(PROJECT / 'tools/maquette_fit.py'), 'fit', '--spec', str(path), '--source', str(root / 'source.png'), '--out', str(root / 'out')], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(before, path.read_bytes())
            for name in ['spec_fit.json', 'fit_report.json', 'fit_overlay.png']:
                self.assertTrue((root / 'out' / name).is_file())
            self.assertIn('MAQUETTE_FIT: PASS', run.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
