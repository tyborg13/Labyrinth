"""Pin the complete approved Seer closure; binding fields alone may change."""
import hashlib
import json
from pathlib import Path
import re
import unittest

PROJECT = Path(__file__).resolve().parents[1]
# rr-26 feedbacks 1 and 2 (32ce9d813) authorize the sleeve/hem pins.
BASELINE = PROJECT / 'tests/rr14/seer_identity.json'


def without_bindings(raw):
    text = raw.decode()
    match = re.search(r'"inputs"\s*:\s*', text)
    _, length = json.JSONDecoder().raw_decode(text[match.end():])
    return (text[:match.end()] + '{}' + text[match.end()+length:]).encode()


class SeerIdentityTests(unittest.TestCase):
    def test_approved_assets_layouts_compiled_motion_and_samples_are_byte_identical(self):
        baseline = json.loads(BASELINE.read_text())
        for filename, expected in baseline['files'].items():
            with self.subTest(file=filename):
                self.assertEqual(hashlib.sha256((PROJECT / filename).read_bytes()).hexdigest(), expected)
        for filename, expected in baseline['binding_only_files'].items():
            with self.subTest(file=filename):
                self.assertEqual(hashlib.sha256(without_bindings((PROJECT / filename).read_bytes())).hexdigest(), expected)
        print('RR14 SEER BYTE IDENTITY: PASS (%d files; only two input-binding objects excluded)' %
              (len(baseline['files']) + len(baseline['binding_only_files'])))


if __name__ == '__main__':
    unittest.main()
