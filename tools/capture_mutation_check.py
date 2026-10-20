#!/usr/bin/env python3
"""Headless cap-01 mutation proof; never edits a production writer or gate."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
TEST_MODULE = PROJECT / 'tests/test_native_frames.py'
TEST_DIRECTORY = PROJECT / 'tests/maquette_cutout'
MUTATION_TIMEOUT_SECONDS = 180


def shifted_crop():
    with tempfile.TemporaryDirectory(prefix='cap01_mutation_', dir=TEST_DIRECTORY) as temporary:
        folder = Path(temporary)
        writer = (TEST_DIRECTORY / 'capture_storage.gd').read_text()
        original = 'var cropped: Image = image.get_region(crop)'
        mutant = 'var cropped: Image = image.get_region(Rect2i(crop.position + Vector2i(1, 0), crop.size) if image.get_width() == 1920 else crop)'
        if writer.count(original) != 1: raise ValueError('Writer mutation target changed')
        (folder / 'capture_storage.gd').write_text(writer.replace(original, mutant))
        fixture = (TEST_DIRECTORY / 'capture_storage_test.gd').read_text()
        # Let the writer finish so Python, independently, must reject its pixels.
        check = '_check(proof.get_data() == expected.get_data(), codec + " RGB board full-reference restoration")'
        if fixture.count(check) != 1: raise ValueError('Fixture mutation target changed')
        (folder / 'capture_storage_test.gd').write_text(fixture.replace(check, 'pass'))
        env = dict(os.environ, CAP01_STORAGE_TEST_SCRIPT=str((folder / 'capture_storage_test.gd').relative_to(PROJECT)))
        result = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_native_frames.py',
                                 '-k', 'godot_storage_roundtrips'], cwd=PROJECT, env=env,
                                capture_output=True, text=True, timeout=MUTATION_TIMEOUT_SECONDS)
        log = result.stdout + result.stderr
        return result.returncode != 0 and 'writer-to-Python reconstruction' in log, log


def bypass_rest():
    sys.path.insert(0, str(PROJECT / 'tools'))
    spec = importlib.util.spec_from_file_location('cap01_mutation_tests', TEST_MODULE)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    from humanoid_cutout import gates
    original = gates.load_frame
    def bypass(path, *args, **kwargs):
        return Image.open(path) if Path(path).name == 'front_rest.png' else original(path, *args, **kwargs)
    output = io.StringIO()
    with patch.object(gates, 'load_frame', side_effect=bypass):
        result = unittest.TextTestRunner(stream=output).run(unittest.TestSuite([
            module.NativeFramesTests('test_native_gate_rest_loader_all_codecs')]))
    log = output.getvalue()
    return not result.wasSuccessful() and 'native rest mismatch' in log, log


def main():
    parser = __import__('argparse').ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, run in (('sample_crop_shift_1px_metadata_unchanged', shifted_crop),
                      ('native_gate_rest_loader_bypassed', bypass_rest)):
        killed, log = run()
        (args.output / (name + '.log')).write_text(log)
        rows.append({'mutation': name, 'killed': killed, 'log': name + '.log'})
        print('CAPTURE MUTATION ' + name + ': ' + ('KILLED' if killed else 'SURVIVED'))
    (args.output / 'mutations.json').write_text(json.dumps(rows, indent=2) + '\n')
    return int(not all(row['killed'] for row in rows))


if __name__ == '__main__': raise SystemExit(main())
