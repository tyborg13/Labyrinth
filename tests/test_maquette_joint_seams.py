"""Local bands, protected paint and report-only CPU/native seam mutations."""
from pathlib import Path
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest, read_json, write_json
from maquette_motion import joint_seams, seam_pose, silhouette, pixels
from maquette_motion.features import source_pixels

FIXTURE_SIZE = 255
FIXTURE_PARENT_RGBA = (71, 42, 19, 255)
FIXTURE_CHILD_RGBA = (29, 53, 91, 255)
FIXTURE_BODY_RECT = (20, 20, 40, 40)
FIXTURE_BOUNDARY_X = 30
FIXTURE_SEPARATION_PX = 3
FIXTURE_FEATURE_RECT = (29, 25, 31, 28)
FIXTURE_FEATURE_STRIP_RECT = (29, 20, 30, 40)
FIXTURE_FEATURE_RGBA = (255, 255, 255, 255)
FIXTURE_MUTATION_YX = (0, 0)
FIXTURE_FOREGROUND_Z = 10
FIXTURE_GATE_SIZE = 40
FIXTURE_GATE_BODY_RECT = (5, 5, 35, 35)
FIXTURE_GATE_INTERIOR_RECT = (6, 6, 34, 34)
FIXTURE_CRACK_RECT = (19, 5, 20, 20)
FIXTURE_EXISTING_HOLE_RECT = (15, 15, 17, 17)
FIXTURE_CURL_BODY_RECT = (35, 10, 39, 20)
FIXTURE_CURL_HOLE_RECT = (36, 12, 38, 18)
FIXTURE_ALLOWED_PROTRUSION_YX = (15, 3)
FIXTURE_EXCESS_PROTRUSION_YX = (15, 2)
FIXTURE_NATIVE_BODY_RECT = (20, 20, 40, 40)
FIXTURE_NATIVE_HOLE_RECT = (25, 25, 27, 27)
FIXTURE_WIDENED_GAP_PX = 2
FIXTURE_LARGE_SEPARATION_PX = 20
FIXTURE_COMPONENT_RECTS = ((10, 10, 13, 11), (20, 20, 24, 21), (30, 30, 32, 31))


def region(rect):
    left, top, right, bottom = rect
    return slice(top, bottom), slice(left, right)


class JointSeamTests(unittest.TestCase):
    def fixture(self, case):
        paint = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), np.uint8)
        left, top, right, bottom = FIXTURE_BODY_RECT
        paint[top:bottom, left:FIXTURE_BOUNDARY_X] = FIXTURE_PARENT_RGBA
        paint[top:bottom, FIXTURE_BOUNDARY_X:right] = FIXTURE_CHILD_RGBA
        write_json(case / 'cutout.json', {'sources': []})
        rows = []
        for view in ('front', 'rear'):
            (case / f'source/{view}').mkdir(parents=True)
            Image.fromarray(paint).save(case / f'source/{view}/processed.png')
            parts = []
            for name, start, end, parent in (('body', left, FIXTURE_BOUNDARY_X, 'root'),
                                             ('child', FIXTURE_BOUNDARY_X, right, 'body')):
                image = np.zeros_like(paint)
                image[top:bottom, start:end] = paint[top:bottom, start:end]
                file = f'{view}_{name}.png'
                Image.fromarray(image).save(case / file)
                parts.append({'name': name, 'bone': name, 'file': file, 'offset': [0, 0], 'z_index': len(parts)})
            layout = {'parts': parts, 'rest_source': f'source/{view}/processed.png',
                      'joints': {'root': {'parent': None}, 'body': {'parent': 'root'}, 'child': {'parent': 'body'}}}
            write_json(case / f'layouts/{view}.json', layout)
            for frame, shift in enumerate((0, FIXTURE_SEPARATION_PX)):
                rows.append({'view': view, 'clip': 'fixture', 'frame': frame, 'parts': {
                    'body': {'transform': [1, 0, 0, 1, 0, 0], 'alpha': 1},
                    'child': {'transform': [1, 0, 0, 1, shift, 0], 'alpha': 1}}})
        return paint, {'samples': rows}

    def test_exact_boundary_length_per_side_reach_cap_and_parent_edge_colours(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            layout = read_json(case / 'layouts/front.json')
            records, images, pending = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(pending, [])
            record = records[0]
            self.assertEqual(record['shared_boundary_px'], 20)
            self.assertEqual(record['maximum_sampled_separation_px'], FIXTURE_SEPARATION_PX)
            self.assertEqual(record['reach_per_side_px'], FIXTURE_SEPARATION_PX + 1)
            self.assertEqual(record['band_width_px'], 2 * (FIXTURE_SEPARATION_PX + 1))
            image = images[record['name']]
            self.assertEqual(int((image[..., 3] > 0).sum()), 160)
            self.assertTrue(np.all(image[image[..., 3] > 0] == FIXTURE_PARENT_RGBA))
            samples['samples'][1]['parts']['child']['transform'][4] = FIXTURE_LARGE_SEPARATION_PX
            capped, images, _ = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(capped[0]['derived_reach_per_side_px'], FIXTURE_LARGE_SEPARATION_PX + 1)
            self.assertEqual(capped[0]['reach_per_side_px'], joint_seams.MAX_BAND_REACH_PX)
            self.assertEqual(capped[0]['band_width_px'], 2 * joint_seams.MAX_BAND_REACH_PX)
            self.assertEqual(int((next(iter(images.values()))[..., 3] > 0).sum()), 160)

    def test_install_preserves_rest_and_paint_and_has_no_full_backing(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            paint, samples = self.fixture(case)
            before = {p: p.read_bytes() for p in case.glob('*_*.png')}
            joint_seams.install(case, samples)
            first = (case / 'seams.json').read_bytes()
            joint_seams.install(case, samples)
            self.assertEqual((case / 'seams.json').read_bytes(), first)
            self.assertEqual(joint_seams.definition_errors(case, samples), [])
            for path, expected in before.items():
                self.assertEqual(path.read_bytes(), expected)
            for view in ('front', 'rear'):
                layout = read_json(case / f'layouts/{view}.json')
                combined = Image.new('RGBA', paint.shape[:2])
                for part in sorted(layout['parts'], key=lambda p: p['z_index']):
                    combined.alpha_composite(Image.open(case / part['file']).convert('RGBA'), tuple(part['offset']))
                np.testing.assert_array_equal(np.asarray(combined), paint)
            self.assertFalse((case / 'backing.json').exists())

    def test_sibling_owner_and_paint_are_the_lower_drawn_part(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            layout = read_json(case / 'layouts/front.json')
            layout['joints']['child']['parent'] = 'root'
            records, surfaces, pending = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(pending, [])
            self.assertEqual(records[0]['parent'], 'body')
            layout['parts'][0]['z_index'] = FIXTURE_FOREGROUND_Z
            records, surfaces, pending = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(records[0]['parent'], 'child')
            self.assertEqual(pending, [])
            self.assertTrue(np.all(next(iter(surfaces.values()))[next(iter(surfaces.values()))[..., 3] > 0] == FIXTURE_CHILD_RGBA))
            # Equal-z native ordering is layout order, so body is underneath.
            layout['parts'][0]['z_index'] = layout['parts'][1]['z_index']
            records, _, _ = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(records[0]['parent'], 'body')
            _, surfaces, pending = joint_seams.derive_view(case, 'front', layout, samples,
                                                          {'body|child': 'TODO_DESIGN_fixture_parent'})
            self.assertEqual(surfaces, {})
            self.assertEqual(len(pending), 1)
            _, surfaces, pending = joint_seams.derive_view(case, 'front', layout, samples, {'body|child': 'body'})
            self.assertEqual(len(surfaces), 1)
            self.assertEqual(pending, [])

    def test_disconnected_bands_become_single_component_nodes_and_specks_are_dropped(self):
        image = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), np.uint8)
        for rect in FIXTURE_COMPONENT_RECTS:
            image[region(rect)] = FIXTURE_PARENT_RGBA
        nodes, discarded = joint_seams.connected_bands('fixture_seam', image)
        self.assertEqual(discarded, [2])
        self.assertEqual(list(nodes), ['fixture_seam_component_01', 'fixture_seam_component_02'])
        self.assertEqual([int((node[..., 3] > 0).sum()) for node in nodes.values()], [4, 3])
        for node in nodes.values():
            self.assertEqual(len(silhouette.components(node[..., 3] > 0)[1]), 1)
        # Split results and naming are deterministic, including equal-size ties.
        repeated, _ = joint_seams.connected_bands('fixture_seam', image)
        for name, expected in nodes.items():
            np.testing.assert_array_equal(repeated[name], expected)

    def test_feature_hole_is_never_target_or_donor(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            layout = read_json(case / 'layouts/front.json')
            feature = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), np.uint8)
            feature[region(FIXTURE_FEATURE_RECT)] = FIXTURE_FEATURE_RGBA
            Image.fromarray(feature).save(case / 'feature.png')
            # Deliberately contaminate the donor, as if an extraction failed.
            # Its protected texels must not propagate into adjacent band paint.
            donor_path = case / layout['parts'][0]['file']
            donor = np.array(Image.open(donor_path))
            donor[(feature[..., 3] > 0) & (donor[..., 3] > 0)] = FIXTURE_FEATURE_RGBA
            Image.fromarray(donor).save(donor_path)
            layout['parts'].append({'name': 'gem', 'feature': 'gem', 'bone': 'body',
                                    'file': 'feature.png', 'offset': [0, 0], 'z_index': FIXTURE_FOREGROUND_Z})
            _, surfaces, _ = joint_seams.derive_view(case, 'front', layout, samples)
            image = next(iter(surfaces.values()))
            self.assertFalse(image[..., 3][feature[..., 3] > 0].any())
            self.assertTrue(np.all(image[image[..., 3] > 0] == FIXTURE_PARENT_RGBA))

    def test_paint_attachment_and_order_mutations_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            joint_seams.install(case, samples)
            layout = read_json(case / 'layouts/front.json')
            seam = layout['parts'][0]
            path = case / seam['file']
            image = np.array(Image.open(path))
            image[(*FIXTURE_MUTATION_YX, 0)] += 1
            Image.fromarray(image).save(path)
            self.assertTrue(any('seam pixels differ' in e for e in joint_seams.definition_errors(case, samples)))
            seam['bone'] = 'child'
            seam['z_index'] = FIXTURE_FOREGROUND_Z
            write_json(case / 'layouts/front.json', layout)
            self.assertTrue(any('attachment/draw order' in e for e in joint_seams.definition_errors(case, samples)))

    def test_feature_owned_region_contributes_to_parent_boundary_without_donating_paint(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            layout = read_json(case / 'layouts/front.json')
            parent_path = case / layout['parts'][0]['file']
            paint = np.array(Image.open(parent_path))
            feature = np.zeros_like(paint)
            feature[region(FIXTURE_FEATURE_STRIP_RECT)] = paint[region(FIXTURE_FEATURE_STRIP_RECT)]
            paint[region(FIXTURE_FEATURE_STRIP_RECT)] = 0
            Image.fromarray(paint).save(parent_path)
            Image.fromarray(feature).save(case / 'feature.png')
            layout['parts'].append({'name': 'gem', 'feature': 'gem', 'logical_part': 'body', 'bone': 'body',
                                    'file': 'feature.png', 'offset': [0, 0], 'z_index': FIXTURE_FOREGROUND_Z})
            # Visible body paint alone no longer touches child. The supplied
            # feature ownership still defines a 20px body/child boundary.
            a, b = (source_pixels(case, p)[..., 3] > 0 for p in layout['parts'][:2])
            self.assertEqual(len(joint_seams.boundary(a, b)), 0)
            records, surfaces, pending = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(pending, [])
            self.assertEqual(records[0]['shared_boundary_px'], 20)
            image = next(iter(surfaces.values()))
            self.assertFalse(image[..., 3][feature[..., 3] > 0].any())
            self.assertTrue(np.all(image[image[..., 3] > 0] == FIXTURE_PARENT_RGBA))

    def test_same_bone_paint_has_zero_joint_separation(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            layout = read_json(case / 'layouts/front.json')
            layout['parts'][1]['bone'] = 'body'
            for row in samples['samples']:
                row['parts']['child'] = row['parts']['body'].copy()
            records, _, pending = joint_seams.derive_view(case, 'front', layout, samples)
            self.assertEqual(pending, [])
            self.assertEqual(records[0]['parent'], 'body')
            self.assertEqual(records[0]['maximum_sampled_separation_px'], 0)
            self.assertEqual(records[0]['reach_per_side_px'], 1)
            self.assertEqual(records[0]['band_width_px'], 2)

    def test_interior_tear_is_measured_even_when_open_to_exterior(self):
        parts = np.zeros((FIXTURE_GATE_SIZE,) * 2, bool)
        parts[region(FIXTURE_GATE_BODY_RECT)] = True
        rest = parts.copy()
        interior = np.zeros_like(parts)
        interior[region(FIXTURE_GATE_INTERIOR_RECT)] = True
        underlay = np.zeros_like(parts)
        self.assertEqual(seam_pose.measure(parts, underlay, rest, interior)[0]['interior_tear_pixels'], 0)
        parts[region(FIXTURE_CRACK_RECT)] = False
        metric, _, _, _ = seam_pose.measure(parts, underlay, rest, interior)
        self.assertEqual(metric['interior_tear_pixels'], 14)
        self.assertEqual(silhouette.measure(parts)[0]['new_holes'], 0)
        underlay[region(FIXTURE_CRACK_RECT)] = True
        self.assertEqual(seam_pose.measure(parts, underlay, rest, interior)[0]['interior_tear_pixels'], 0)

    def test_negative_space_and_protrusion_are_measured_without_clamping(self):
        parts = np.zeros((FIXTURE_GATE_SIZE,) * 2, bool)
        parts[region(FIXTURE_GATE_BODY_RECT)] = True
        rest = parts.copy()
        rest[region(FIXTURE_EXISTING_HOLE_RECT)] = False
        parts[region(FIXTURE_EXISTING_HOLE_RECT)] = False
        parts[region(FIXTURE_CURL_BODY_RECT)] = True
        parts[region(FIXTURE_CURL_HOLE_RECT)] = False
        underlay = np.zeros_like(parts)
        interior = rest.copy()
        metric, _, _, _ = seam_pose.measure(parts, underlay, rest, interior)
        self.assertEqual(metric['natural_negative_space_pixels'], 12)
        self.assertEqual(metric['interior_tear_pixels'], 0)
        underlay[FIXTURE_ALLOWED_PROTRUSION_YX] = True
        self.assertEqual(seam_pose.measure(parts, underlay, rest, interior)[0]['underlay_protrusion_width_px'], 2)
        underlay[FIXTURE_EXCESS_PROTRUSION_YX] = True
        self.assertEqual(seam_pose.measure(parts, underlay, rest, interior)[0]['underlay_protrusion_width_px'], 3)

    def test_native_layers_must_match_composition_and_dimensions(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            shape = (pixels.PROOF_DEFAULTS['canvas_size'],) * 2 + (4,)
            parts, seams = np.zeros(shape, np.uint8), np.zeros(shape, np.uint8)
            parts[region(FIXTURE_NATIVE_BODY_RECT)] = FIXTURE_PARENT_RGBA
            parts[region(FIXTURE_NATIVE_HOLE_RECT)] = 0
            seams[region(FIXTURE_NATIVE_HOLE_RECT)] = FIXTURE_PARENT_RGBA
            composed = parts | seams
            for name, image in (('parts', parts), ('seams', seams), ('composed', composed)):
                Image.fromarray(image).save(case / (name + '.png'))
            row = {'view': 'front', 'clip': 'fixture', 'frame': 0}
            layers = {'directory': case, 'frames': [dict(row, parts_file='parts.png', seams_file='seams.png')]}
            full = {'directory': case, 'frames': [dict(row, file='composed.png')]}
            self.assertEqual(seam_pose.native_consistency_errors(layers, full), [])
            Image.fromarray(parts).save(case / 'composed.png')
            self.assertTrue(any('differ from composed' in e for e in seam_pose.native_consistency_errors(layers, full)))
            Image.fromarray(parts[:FIXTURE_GATE_SIZE, :FIXTURE_GATE_SIZE]).save(case / 'composed.png')
            self.assertTrue(any('dimensions' in e for e in seam_pose.native_consistency_errors(layers, full)))

    def test_widen_joint_mutation_is_report_only_but_native_agreement_still_blocks(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            samples['samples'] = [r for r in samples['samples'] if r['frame'] == 0]
            self.assertTrue(seam_pose.report(case, samples)['ok'])
            samples['samples'][0]['parts']['child']['transform'][4] = FIXTURE_WIDENED_GAP_PX
            cpu = seam_pose.report(case, samples)
            self.assertTrue(cpu['ok'], cpu['errors'])
            self.assertEqual(cpu['poses'][0]['interior_tear_pixels'], 36)
            self.assertEqual(cpu['max_by_clip']['front_fixture']['interior_tear_pixels']['interior_tear_pixels'], 36)
            native = {'directory': case, 'frames': []}
            for row in samples['samples']:
                layout = read_json(case / f'layouts/{row["view"]}.json')
                mask = silhouette.compose(case, layout, row)
                parts = np.zeros((*mask.shape, 4), np.uint8)
                parts[mask] = FIXTURE_PARENT_RGBA
                frame = {k: row[k] for k in ('view', 'clip', 'frame')}
                for name, image in (('parts', parts), ('seams', np.zeros_like(parts))):
                    file = row['view'] + '_' + name + '.png'
                    Image.fromarray(image).save(case / file)
                    frame[name + '_file'] = file
                    frame[name + '_sha256'] = digest(case / file)
                frame['reference'] = dict(row['parts']['body'], bone='body')
                frame['reference_transform'] = row['parts']['body']['transform'].copy()
                for kind, source in zip(('rest', 'interior'), seam_pose.reference_images(case, layout)):
                    image = pixels.render(source, pixels.unpack(frame['reference_transform']))
                    file = row['view'] + '_' + kind + '.png'
                    Image.fromarray(image).save(case / file)
                    frame[kind + '_file'] = file
                    frame[kind + '_sha256'] = digest(case / file)
                native['frames'].append(frame)
            saved = seam_pose.report(case, samples, native)
            self.assertTrue(saved['ok'], saved['errors'])
            self.assertEqual([r['interior_tear_pixels'] for r in cpu['poses']],
                             [r['interior_tear_pixels'] for r in saved['poses']])
            native['frames'][0]['reference_transform'][4] += FIXTURE_WIDENED_GAP_PX
            self.assertTrue(any('independently moved' in e for e in seam_pose.report(case, samples, native)['errors']))
            native['frames'].pop()
            self.assertTrue(any('missing native' in e for e in seam_pose.report(case, samples, native)['errors']))
        print('MAQUETTE SEAM MUTATION: CPU/native gap reported; independent native reference rejected')

    def test_rest_identity_checks_current_paint_without_writing_proof(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            self.fixture(case)
            self.assertTrue(pixels.rest_identity(case)['ok'])
            path = case / 'front_body.png'
            image = np.array(Image.open(path))
            image[FIXTURE_BODY_RECT[1], FIXTURE_BODY_RECT[0], 0] += 1
            Image.fromarray(image).save(path)
            result = pixels.rest_identity(case)
            self.assertFalse(result['ok'])
            self.assertEqual(result['views']['front']['different_pixels'], 1)
            self.assertEqual(result['views']['rear']['different_pixels'], 0)
            self.assertFalse((case / 'proof/rest_identity.json').exists())

    def test_report_only_metrics_do_not_block_promotion_prerequisites(self):
        from maquette_cutout_build import validate_derived_material
        from cutout_pipeline.cases import CutoutError
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            _, samples = self.fixture(case)
            joint_seams.install(case, samples)
            write_json(case / 'proof/continuity_samples.json', samples)
            write_json(case / 'hidden_fills/index.json', {'pending_design': []})
            # Independent blocking gates are prevalidated in this seam-only fixture.
            proof = {'ok': True, 'TODO_DESIGN': [], 'exposed_hidden': {'ok': True}, 'seams': {'ok': True, 'max_by_clip': {
                'fixture': {'interior_tear_pixels': FIXTURE_LARGE_SEPARATION_PX,
                            'underlay_protrusion_width_px': FIXTURE_LARGE_SEPARATION_PX}}}}
            write_json(case / 'proof/continuity.json', proof)
            # This fixture isolates seam acceptance; freshness has its own
            # case-copy mutation tests and is prevalidated here.
            with patch('maquette_motion.certificates.require_current') as current:
                validate_derived_material(case)
                current.assert_called_once_with(case)
            proof['ok'] = False
            write_json(case / 'proof/continuity.json', proof)
            with self.assertRaisesRegex(CutoutError, 'blocking derive-time'):
                validate_derived_material(case)
            proof.update(ok=True, TODO_DESIGN=[{'name': 'TODO_DESIGN_fixture_missing_owner'}])
            write_json(case / 'proof/continuity.json', proof)
            with self.assertRaisesRegex(CutoutError, 'blocking derive-time'):
                validate_derived_material(case)


if __name__ == '__main__':
    unittest.main()
