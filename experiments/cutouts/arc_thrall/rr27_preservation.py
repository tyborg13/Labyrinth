"""Exact feedback-1 exceptions for two removed continuation copies.

These verify the director's edit against the original bytes/pixels. They do
not repin a baseline or permit unrelated changes to a texture or layout.
"""
from copy import deepcopy
from io import BytesIO
import json

import numpy as np
from PIL import Image

from rr27_build import PROJECT, CASE, ASSETS

FAR_COPY = 'mq7b_continuation_leg_far'
NEAR_COPY = 'mq7b_continuation_leg_near'
REAR_LAYOUTS = ('experiments/cutouts/arc_thrall/rr11/layouts/rear.json',
    'assets/units/arc_thrall_cutout/rear.json',
    'assets/units/arc_thrall_cutout/humanoid_v2/rear.json')
REMOVED_COPY_OUTPUTS = {
    'experiments/cutouts/arc_thrall/rr11/pieces/rear/mq7b_continuation_leg_far.png': [53,97],
    'experiments/cutouts/arc_thrall/rr11/checks/rear/mq7b_continuation_leg_far.png': [53,97],
    'experiments/cutouts/arc_thrall/rr11/tucks/rear_leg_far.png': [171,218],
    'assets/units/arc_thrall_cutout/humanoid_v2/rear/mq7b_continuation_leg_far.png': [53,97]
}


def copy_removal_is_exact(relative, original):
    point = REMOVED_COPY_OUTPUTS.get(relative)
    if point is None:
        return False
    expected_image = Image.open(BytesIO(original)).copy()
    expected_image.putpixel(tuple(point),0 if expected_image.mode in ('1','L') else (0,0,0,0))
    expected = np.asarray(expected_image.convert('RGBA'))
    current = np.asarray(Image.open(PROJECT / relative).convert('RGBA'))
    return np.array_equal(current,expected)


def expected_rear_layout(original, source_sha256):
    expected = deepcopy(original)
    recipe = expected['gait_continuations'][NEAR_COPY]
    recipe['texels'] = [row for row in recipe['texels'] if row[:2] != [17,60]]
    if 'proof_layers' in expected:
        expected['proof_layers'][FAR_COPY]['source_sha256'] = source_sha256
    return expected


def assert_original_rear_delta(test, relative, baseline):
    from rr27_check import committed
    from rr24_baseline import canonical
    from cutout_pipeline.cases import digest, read_json
    original = committed(relative)
    if relative in REMOVED_COPY_OUTPUTS:
        import hashlib
        test.assertEqual(hashlib.sha256(original).hexdigest(),baseline['files'][relative]['sha256'])
        test.assertTrue(copy_removal_is_exact(relative,original),relative)
    elif relative in REAR_LAYOUTS:
        value = json.loads(original)
        pin = deepcopy(value)
        pin.pop('rest_source_sha256',None)
        test.assertEqual(canonical(pin),baseline['files'][relative]['canonical_layout_sha256'])
        expected = expected_rear_layout(value,digest(CASE / 'pieces/rear/mq7b_continuation_leg_far.png'))
        test.assertEqual(read_json(PROJECT / relative),expected,relative)
    else:
        raise ValueError('Not an authorized rear continuation output: ' + relative)
