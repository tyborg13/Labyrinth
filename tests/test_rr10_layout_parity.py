"""Authoring, production and density/rebaker layouts describe the same rig."""
import copy
import json
from pathlib import Path
import unittest

PROJECT = Path(__file__).resolve().parents[1]
CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
ASSETS = PROJECT / 'assets/units/hoarfrost_seer_cutout'
AUTHORING_FIELDS = ('proof_layers', 'proof_joint_seams', 'proof_rest_holes',
                    'ownership_overrides', 'features', 'occluded_surfaces', 'covered_surface_masks')


def normalize(layout):
    result = copy.deepcopy(layout)
    for name in AUTHORING_FIELDS:
        result.pop(name, None)
    # Approved-source rest and density-treated native rest have independent
    # fingerprints; filenames/roots differ, while rig geometry must not.
    result.pop('rest_source_sha256', None)
    result['rest_source'] = 'rest.png'
    result['motion_data'] = Path(result['motion_data']).name
    for part in result['parts'] + result['joint_meshes']:
        part['file'] = result['facing'] + '/' + Path(part['file']).name
    return result


class LayoutParityTests(unittest.TestCase):
    def test_all_three_layouts_have_normalized_parity_in_both_views(self):
        for view in ('front', 'rear'):
            paths = [CASE / f'layouts/{view}.json', ASSETS / f'humanoid_v2/{view}.json', ASSETS / f'{view}.json']
            layouts = [json.loads(path.read_bytes()) for path in paths]
            expected = normalize(layouts[0])
            for path, layout in zip(paths, layouts):
                with self.subTest(path=path):
                    self.assertEqual(normalize(layout), expected)
            for index, layout in enumerate(layouts):
                mutant = copy.deepcopy(layout)
                mutant['parts'][0]['z_index'] += 1
                with self.subTest(view=view, changed_copy=index):
                    self.assertNotEqual(normalize(mutant), expected)


if __name__ == '__main__':
    unittest.main()
