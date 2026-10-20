"""Rebind unchanged approved evidence, preserving every non-binding byte."""
import json
from pathlib import Path
import re
import sys

PROJECT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'tests')]
from humanoid_cutout.gates import bindings
from test_rr14_seer_identity import BASELINE_COMMIT, INVENTORY, without_bindings
from unit_preservation import read_bytes

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'


def main():
    expected = json.loads(INVENTORY.read_text())['binding_only_files']
    current = bindings(CASE)
    for filename in expected:
        path = PROJECT / filename
        raw = path.read_bytes()
        if without_bindings(raw) != without_bindings(read_bytes(PROJECT, BASELINE_COMMIT, filename)):
            raise ValueError('Refusing changed evidence payload: ' + filename)
        text = raw.decode()
        match = re.search(r'"inputs"\s*:\s*', text)
        previous, length = json.JSONDecoder().raw_decode(text[match.end():])
        # Preserve the surrounding serializer and exact pose/review payload.
        compact = '\n' not in text
        replacement = json.dumps(current, sort_keys=True, separators=(',', ':')) if compact else json.dumps(current, indent=2)
        if not compact: replacement = replacement.replace('\n', '\n  ')
        new = (text[:match.end()] + replacement + text[match.end()+length:]).encode()
        if without_bindings(raw) != without_bindings(new): raise AssertionError('Evidence payload changed')
        path.write_bytes(new)
        print('RR14 REBIND: %s (%d -> %d inputs; evidence payload unchanged)' % (path.name, len(previous), len(current)))


if __name__ == '__main__':
    main()
