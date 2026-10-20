"""Keep rr-20's original inventory pinned while mq-11 adds authoring inputs.

The new authoring files are checked by the live maquette manifest test. This
adapter removes only mq-11's explicitly named additions before checking the
older rr-20 receipt. Every original line and every paint/source pin stays live.
"""
from contextlib import contextmanager
import hashlib
from pathlib import Path
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
# Current integration HEAD supplied to this prepared worktree, rather than
# the older task helper's historical branch-creation base.
BASELINE_COMMIT = 'ee03daf93cf6625085a8021da3e08064e6c74216'
MANIFEST = PROJECT / 'spec/art_identity/maquettes/hollow_mimic/COMMIT_MANIFEST.txt'
MQ11_LINES = frozenset({
    '# mq-11 adds candidate authoring inputs; native scratch outputs live under tests/mq11_proof/.',
    'owner_review/README.md', 'owner_review/__init__.py', 'owner_review/baseline.json',
    'owner_review/candidate.py', 'owner_review/design.json', 'owner_review/measurements.py',
    'owner_review/native_probe.py', 'owner_review/preservation.py', 'owner_review/proof.py',
    'owner_review/workflow.py'})


def inherited_inventory(blob):
    return b''.join(line for line in blob.splitlines(keepends=True)
                    if line.rstrip(b'\r\n').decode('utf-8') not in MQ11_LINES)


@contextmanager
def rr20_inventory_context(gates):
    original = gates.digest

    def digest(path):
        path = Path(path)
        if path.resolve() == MANIFEST.resolve():
            return hashlib.sha256(inherited_inventory(path.read_bytes())).hexdigest()
        return original(path)

    with patch.object(gates, 'digest', digest):
        yield
