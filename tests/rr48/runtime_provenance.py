"""Recover exact earlier certificates across rr-48's opt-in runtime additions.

Only pinned before/after source bytes are normalized. The independent production
pose comparison covers every earlier humanoid clip; corruptions remain visible
to the original certificate assertions.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name('runtime_binding_changes.json')
UNBOUND_PROOF_ADAPTERS = {'tests/maquette_cutout/proof_inputs.gd',
                          'tools/maquette_motion/gates.py'}


def prior_runtime_bytes(path, content):
    manifest = json.loads(MANIFEST.read_text())
    delta = manifest['bindings'].get(path)
    if delta is None or hashlib.sha256(content).hexdigest() != delta['after']:
        return content
    if delta['before'] is None:
        raise ValueError('Added runtime has no earlier bytes: ' + path)
    original = subprocess.check_output(
        ['git', 'show', manifest['baseline_revision'] + ':' + path], cwd=ROOT)
    if hashlib.sha256(original).hexdigest() != delta['before']:
        raise ValueError('Invalid original rr-48 runtime binding: ' + path)
    return original


def normalize_rig_bindings(poses, inputs):
    manifest = json.loads(MANIFEST.read_text())
    added = 'runtime:scripts/maquette_cutout_runtime/humanoid_grip.gd'
    if added not in inputs:
        return poses  # Earlier synthetic provenance tests have no new runtime.
    normalized = poses
    for path, delta in manifest['bindings'].items():
        key = 'runtime:' + path
        # The older humanoid binder does not traverse these two separate
        # maquette proof adapters. Bound adapters still require exact bytes.
        if path in UNBOUND_PROOF_ADAPTERS and key not in inputs:
            continue
        after = delta['after']
        if inputs.get(key) != after or hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != after:
            raise ValueError('Changed rr-48 runtime binding: ' + key)
        if delta['before'] is None:
            token = (json.dumps(key) + ':' + json.dumps(after) + ',').encode()
            if normalized.count(token) != 1:
                raise ValueError('Invalid rr-48 added binding: ' + key)
            normalized = normalized.replace(token, b'', 1)
        else:
            prior_runtime_bytes(path, (ROOT / path).read_bytes())
            if normalized.count(after.encode()) != 1:
                raise ValueError('Ambiguous rr-48 runtime binding: ' + key)
            normalized = normalized.replace(after.encode(), delta['before'].encode(), 1)
    return normalized
