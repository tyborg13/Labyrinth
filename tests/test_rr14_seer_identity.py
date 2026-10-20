"""rr-14 preserves Seer in its own range; later Seer units own their changes."""
import json
from pathlib import Path
import sys
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from unit_preservation import changed_paths, read_bytes

# merge-base(e08e4e296^1, e08e4e296^2), through rr-14's final unit head.
# Never advance these endpoints to accommodate a later figure revision.
BASELINE_COMMIT = '66d07be81f36d10106b1a2548f5c8a08fe3364c5'
UNIT_HEAD = '5a97e2b28bccd407a970dc0bfda4beb70fc11ea9'
INVENTORY = PROJECT / 'tests/rr14/seer_identity.json'


def without_bindings(raw):
    """Remove only the top-level inputs object, preserving every other byte."""
    text = raw.decode()
    decoder = json.JSONDecoder()
    position = len(text) - len(text.lstrip())
    if text[position:position + 1] != '{':
        raise ValueError('Evidence must be a JSON object')
    position += 1
    while True:
        while text[position].isspace():
            position += 1
        if text[position] == '}':
            raise ValueError('Evidence has no top-level inputs object')
        key, position = decoder.raw_decode(text, position)
        while text[position].isspace():
            position += 1
        if text[position] != ':':
            raise ValueError('Invalid evidence object')
        position += 1
        while text[position].isspace():
            position += 1
        value, end = decoder.raw_decode(text, position)
        if key == 'inputs':
            if not isinstance(value, dict):
                raise ValueError('Evidence inputs must be an object')
            return (text[:position] + '{}' + text[end:]).encode()
        position = end
        while text[position].isspace():
            position += 1
        if text[position] == ',':
            position += 1


class SeerIdentityTests(unittest.TestCase):
    def test_approved_assets_layouts_compiled_motion_and_samples_are_byte_identical(self):
        inventory = json.loads(INVENTORY.read_text())
        changed = set(changed_paths(PROJECT, BASELINE_COMMIT, UNIT_HEAD))
        for filename in inventory['files']:
            with self.subTest(file=filename):
                self.assertNotIn(filename, changed, 'rr-14 changed protected Seer bytes: ' + filename)
        for filename in inventory['binding_only_files']:
            with self.subTest(file=filename):
                self.assertEqual(without_bindings(read_bytes(PROJECT, BASELINE_COMMIT, filename)),
                                 without_bindings(read_bytes(PROJECT, UNIT_HEAD, filename)), filename)
        print('RR14 SEER RANGE IDENTITY: PASS (%d files; only two input-binding objects excluded)' %
              (len(inventory['files']) + len(inventory['binding_only_files'])))


if __name__ == '__main__':
    unittest.main()
