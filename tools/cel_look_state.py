"""Generated cel paths and content stamp, shared by build/status/export."""
import hashlib
import json
from pathlib import Path

import numpy as np
import PIL

PROJECT = Path(__file__).resolve().parents[1]
OUTPUT_DIRECTORY = 'cel_look_variants'
CONFIG = PROJECT / 'tools/cel_look.json'
TOOL_INPUTS = (
    'tools/cel_look.py', 'tools/cel_look_inventory.py', 'tools/cel_look_state.py',
    'spec/peer_benchmark/staged/cel-01/reference_filter.py',
)


def variant_relative(source):
    # PNG bytes with an unrecognized extension: no Godot import or sidecars.
    return source + '.celpng'


def library_versions():
    return {'numpy': np.__version__, 'pillow': PIL.__version__}


def input_stamp(project, entries, config):
    digest = hashlib.sha256()

    def add(name, data):
        digest.update(name.encode() + b'\0')
        digest.update(len(data).to_bytes(8, 'little'))
        digest.update(data)

    add('inventory', json.dumps(entries, sort_keys=True).encode())
    add('config', json.dumps(config, sort_keys=True).encode())
    add('libraries', json.dumps(library_versions(), sort_keys=True).encode())
    for name in sorted({e[key] for e in entries for key in ('path', 'rest')}):
        add(name, (project / name).read_bytes())
    for name in TOOL_INPUTS:
        add(name, (PROJECT / name).read_bytes())
    return digest.hexdigest()


def expected_manifest(project, entries, config):
    """Expected pack identity, independent of any locally generated variants."""
    return {'stamp': input_stamp(project, entries, config),
            'files': {e['path']: e['scope'] for e in entries},
            'variants': {e['path']: variant_relative(e['path']) for e in entries}}


def status(project, output, entries, config):
    """Return current only for the exact inputs and every intact output."""
    try:
        manifest = json.loads((output / 'manifest.json').read_text())
        if manifest.get('stamp') != input_stamp(project, entries, config):
            return False, 'input stamp differs'
        expected = {e['path']: e['scope'] for e in entries}
        variants = {path: variant_relative(path) for path in expected}
        if manifest.get('files') != expected or manifest.get('variants') != variants:
            return False, 'inventory differs'
        for path in variants.values():
            variant = output / path
            if not variant.is_file():
                return False, 'missing ' + path
            if hashlib.sha256(variant.read_bytes()).hexdigest() != manifest.get('sha256', {}).get(path):
                return False, 'damaged ' + path
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        return False, str(exc)
    return True, 'current'
