"""Exposed hidden material, interior donors and immutable-seed regressions."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest, read_json, write_json, CutoutError
from maquette_motion import hidden_material, material_palette, continuity, material_provenance
from maquette_motion.bleed import edge_texels

FIXTURE_SIZE = 12
FIXTURE_OUTLINE_RGBA = (20, 16, 21, 255)
FIXTURE_INTERIOR_RGBA = (109, 72, 54, 255)
FIXTURE_LOW_LUMA_RGBA = (3, 4, 5, 255)
FIXTURE_RULES = {'outline_palette': [list(FIXTURE_OUTLINE_RGBA[:3])], 'visible_luma_cutoff': 9.125}
FIXTURE_LAYOUT = {'parts': [{'name': 'visible'}, {'name': 'hidden', 'hidden_material': True},
                             {'name': 'seam', 'seam_underlay': True}]}
FIXTURE_MARGIN_PX = 2
FIXTURE_DERIVED_BLOCK = (7, 7, 10, 10)
FIXTURE_VISIBLE_CROP = (2, 2, 8, 8)
FIXTURE_ROTATED_TRANSFORM = [0, 1, -1, 0, 16, 0]


class HiddenMaterialTests(unittest.TestCase):
    def frame(self):
        image = np.empty((FIXTURE_SIZE, FIXTURE_SIZE, 4), dtype=np.uint8)
        image[:] = FIXTURE_INTERIOR_RGBA
        return image, np.zeros(image.shape[:2], dtype=np.int32)

    def test_full_three_by_three_block_is_blocking(self):
        image, painter = self.frame()
        image[3:6, 3:6], painter[3:6, 3:6] = FIXTURE_OUTLINE_RGBA, 1
        metric, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, np.zeros(painter.shape, bool))
        self.assertEqual(metric['exposed_hidden_pixels'], 9)
        self.assertEqual(metric['largest_dark_component'], 9)
        self.assertEqual(metric['slab_components'], 1)

    def test_two_pixel_lines_and_visible_paint_are_not_slabs(self):
        image, painter = self.frame()
        image[3:5, 2:10], painter[3:5, 2:10] = FIXTURE_OUTLINE_RGBA, 1
        metric, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, np.zeros(painter.shape, bool))
        self.assertEqual(metric['largest_dark_component'], 16)
        self.assertEqual(metric['slab_components'], 0)
        painter[:] = 0
        metric, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, np.ones(painter.shape, bool))
        self.assertEqual(metric['exposed_hidden_pixels'], 0)

    def test_seam_and_hidden_painters_share_the_same_component_gate(self):
        image, painter = self.frame()
        image[3:6, 3:6] = FIXTURE_LOW_LUMA_RGBA
        painter[3:6, 3:5], painter[3:6, 5:6] = 1, 2
        metric, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, np.zeros(painter.shape, bool))
        self.assertEqual(metric['slab_components'], 1)
        self.assertEqual(metric['slab_painters'], {'hidden': 6, 'seam': 3})

    def test_same_dark_block_blocks_derived_texels_but_only_reports_approved_paint(self):
        image, painter = self.frame()
        image[3:6, 3:6], painter[3:6, 3:6] = FIXTURE_OUTLINE_RGBA, 1
        approved = np.zeros(painter.shape, bool)
        derived, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, approved)
        self.assertEqual(derived['slab_components'], 1)
        self.assertEqual(derived['largest_approved_hidden_dark_component'], 0)
        approved[3:6, 3:6] = True
        painted, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, approved)
        self.assertEqual(painted['slab_components'], 0)
        self.assertEqual(painted['largest_dark_component'], 0)
        self.assertEqual(painted['largest_approved_dark_component'], 9)
        self.assertEqual(painted['largest_approved_hidden_dark_component'], 9)
        # Approved pixels cannot bridge a derived two-pixel line into a slab.
        approved[3:6, 3:5] = False
        mixed, _, _ = hidden_material.measure(image, painter, FIXTURE_LAYOUT, FIXTURE_RULES, approved)
        self.assertEqual(mixed['slab_components'], 0)
        self.assertEqual(mixed['largest_dark_component'], 6)

    def test_texel_provenance_uses_original_mask_rgba_and_the_posed_transform(self):
        with tempfile.TemporaryDirectory() as directory:
            case = Path(directory)
            source = np.empty((FIXTURE_SIZE, FIXTURE_SIZE, 4), np.uint8)
            source[:] = FIXTURE_INTERIOR_RGBA
            (case / 'source/front').mkdir(parents=True)
            Image.fromarray(source).save(case / 'source/front/processed.png')
            mask = np.zeros(source.shape[:2], bool)
            mask[3:6, 3:6] = True
            seed = np.zeros_like(source)
            seed[mask] = FIXTURE_OUTLINE_RGBA
            (case / 'hidden_fills').mkdir()
            Image.fromarray(seed).save(case / 'hidden_fills/front_body.png')
            (case / 'registered').mkdir()
            np.save(case / 'registered/front_hidden_body.npy', mask)
            write_json(case / 'hidden_fills/index.json', {'requests': [{'view': 'front', 'part': 'body',
                'preview': 'hidden_fills/front_body.png', 'preview_sha256': digest(case / 'hidden_fills/front_body.png'),
                'hidden_mask_sha256': hashlib.sha256(mask.tobytes()).hexdigest(),
                'outputs': [{'output_rgba_sha256': hashlib.sha256(seed[3:6, 3:6].tobytes()).hexdigest()}]}]})
            runtime = seed.copy()
            left, top, right, bottom = FIXTURE_DERIVED_BLOCK
            runtime[top:bottom, left:right] = FIXTURE_OUTLINE_RGBA
            part = {'name': 'body', 'bone': 'body', 'hidden_material': True, 'offset': [0, 0], 'z_index': 0}
            layout = {'parts': [part]}
            images = {'body': Image.fromarray(runtime)}
            classes, counts = material_provenance.source_classes(case, 'front', layout, images)
            self.assertEqual(counts['approved_painted_texels'], 9)
            self.assertEqual(counts['derived_texels'], 9)
            row = {'parts': {'body': {'transform': FIXTURE_ROTATED_TRANSFORM, 'alpha': 1}}}
            image, painter, approved = hidden_material.render_layers(case, layout, row, images, classes)
            metric, _, _ = hidden_material.measure(image, painter, layout, FIXTURE_RULES, approved)
            self.assertEqual(metric['slab_pixels'], 9)
            self.assertEqual(metric['largest_approved_hidden_dark_component'], 9)
            # Editing an original texel is derived; equal-colour dilation does
            # not inherit the provenance of its nearest painted donor.
            runtime[3, 3] = FIXTURE_LOW_LUMA_RGBA
            classes, counts = material_provenance.source_classes(case, 'front', layout, {'body': Image.fromarray(runtime)})
            self.assertEqual(counts['approved_painted_texels'], 8)
            self.assertEqual(counts['derived_texels'], 10)
            # Every seam texel is derived, even over matching approved paint.
            seam = dict(part, seam_underlay=True)
            _, counts = material_provenance.source_classes(case, 'front', {'parts': [seam]}, images)
            self.assertEqual(counts['approved_painted_texels'], 0)
            x, y, right, bottom = FIXTURE_VISIBLE_CROP
            visible = dict(part, hidden_material=False, offset=[x, y])
            _, counts = material_provenance.source_classes(case, 'front', {'parts': [visible]},
                {'body': Image.fromarray(source[y:bottom, x:right])})
            self.assertEqual(counts['derived_texels'], 0)
            self.assertEqual(counts['approved_painted_texels'], (right - x) * (bottom - y))
            # A generated edit is blocking even in a normally visible node.
            altered = source[y:bottom, x:right].copy()
            altered[:3, :3] = FIXTURE_OUTLINE_RGBA
            visible_layout = {'parts': [visible]}
            visible_images = {'body': Image.fromarray(altered)}
            classes, counts = material_provenance.source_classes(case, 'front', visible_layout, visible_images)
            self.assertEqual(counts['derived_texels'], 9)
            image, painter, approved = hidden_material.render_layers(case, visible_layout, row, visible_images, classes)
            metric, _, _ = hidden_material.measure(image, painter, visible_layout, FIXTURE_RULES, approved)
            self.assertEqual(metric['slab_pixels'], 9)
            self.assertEqual(metric['exposed_hidden_pixels'], 0)

    def test_both_replication_paths_exclude_nearby_outline_donors(self):
        seed = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), dtype=np.uint8)
        seed[5, 4], seed[5, 8] = FIXTURE_OUTLINE_RGBA, FIXTURE_INTERIOR_RGBA
        target = np.zeros(seed.shape[:2], dtype=bool)
        target[5, 5] = True
        for replicate in (continuity.nearest_existing, edge_texels):
            with self.subTest(replicate=replicate.__name__):
                np.testing.assert_array_equal(replicate(seed, target)[5, 5], FIXTURE_OUTLINE_RGBA)
                np.testing.assert_array_equal(replicate(seed, target, FIXTURE_RULES)[5, 5], FIXTURE_INTERIOR_RGBA)
                seed_without_interior = seed.copy()
                seed_without_interior[5, 8] = 0
                with self.assertRaisesRegex(CutoutError, 'TODO_DESIGN_.*interior_donor'):
                    replicate(seed_without_interior, target, FIXTURE_RULES)

    def test_support_search_restarts_at_original_fill_without_foreign_seed_growth(self):
        with tempfile.TemporaryDirectory() as directory:
            case = Path(directory)
            requests = []
            write_json(case / 'cutout.json', {'character_id': 'fixture'})
            for view in ('front', 'rear'):
                source = np.zeros((255, 255, 4), dtype=np.uint8)
                source[10:60, 10:60] = FIXTURE_INTERIOR_RGBA
                source[10:15, 10:60] = FIXTURE_OUTLINE_RGBA
                (case / f'source/{view}').mkdir(parents=True)
                Image.fromarray(source).save(case / f'source/{view}/processed.png')
                mask = np.zeros((255, 255), dtype=bool)
                mask[30:32, 30:32] = True
                seed = np.zeros_like(source)
                seed[mask] = FIXTURE_INTERIOR_RGBA
                runtime = f'hidden/{view}/body.png'
                (case / f'hidden/{view}').mkdir(parents=True)
                Image.fromarray(seed).save(case / runtime)
                preview = f'hidden_fills/{view}_body.png'
                (case / 'hidden_fills').mkdir(exist_ok=True)
                Image.fromarray(seed).save(case / preview)
                (case / 'registered').mkdir(exist_ok=True)
                np.save(case / f'registered/{view}_hidden_body.npy', mask)
                requests.append({'view': view, 'part': 'body', 'preview': preview,
                                 'preview_sha256': digest(case / preview),
                                 'hidden_mask_sha256': hashlib.sha256(mask.tobytes()).hexdigest(),
                                 'outputs': [{'output_rgba_sha256': hashlib.sha256(seed[30:32, 30:32].tobytes()).hexdigest()}]})
                write_json(case / f'layouts/{view}.json', {'parts': [{'name': 'body', 'bone': 'body',
                    'hidden_material': True, 'file': runtime, 'offset': [0, 0], 'bbox': [0, 0, 255, 255]}]})
            write_json(case / 'hidden_fills/index.json', {'parameters': {'outline_tone': list(FIXTURE_OUTLINE_RGBA[:3])}, 'requests': requests})
            continuity.underlays(case, FIXTURE_MARGIN_PX)
            first = {v: np.array(Image.open(case / f'hidden/{v}/body.png')) for v in ('front', 'rear')}
            # A prior generated/orphan pixel must never become a source seed.
            for view in ('front', 'rear'):
                mutant = first[view].copy()
                mutant[50, 50] = FIXTURE_OUTLINE_RGBA
                Image.fromarray(mutant).save(case / f'hidden/{view}/body.png')
            continuity.underlays(case, 1)
            continuity.underlays(case, FIXTURE_MARGIN_PX)
            for view in ('front', 'rear'):
                np.testing.assert_array_equal(np.array(Image.open(case / f'hidden/{view}/body.png')), first[view])

    def test_promotion_cannot_use_a_pre_gate_or_failing_material_certificate(self):
        from unittest.mock import patch
        import maquette_cutout_build
        from maquette_motion import joint_seams, silhouette
        with tempfile.TemporaryDirectory() as directory:
            case = Path(directory)
            write_json(case / 'proof/continuity_samples.json', {'samples': []})
            for certificate in ({'ok': True}, {'ok': True, 'exposed_hidden': {'ok': False}}):
                write_json(case / 'proof/continuity.json', certificate)
                with patch.object(joint_seams, 'definition_errors', return_value=[]), patch.object(silhouette, 'part_report', return_value={'ok': True}):
                    with self.assertRaisesRegex(CutoutError, 'exposed hidden-material gate'):
                        maquette_cutout_build.validate_derived_material(case)


if __name__ == '__main__':
    unittest.main()
