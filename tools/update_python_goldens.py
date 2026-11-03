#!/usr/bin/env python3
"""Regenerate a Python output golden in one command, then review its Git diff.

Only test expectations are written. Approved production art/data are never
updated by this helper. Engine work always goes through the task runner.
"""
from __future__ import annotations

import argparse
import difflib
import gzip
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT), str(ROOT / 'tools')]
GOLDENS = ROOT / 'tests/goldens'
MAQUETTES = ('arc_thrall', 'briar_weaver', 'burrow_grub', 'ember_tick',
             'glacial_mirror', 'hoarfrost_seer', 'hollow_mimic', 'slag_mortar')
ENGINE_TIMEOUT_SECONDS = 120


def raw_steps():
    from tests.test_art_identity_gate import GateTests, RAW_STEP_FIXTURE_REGION, gate
    fixture = GateTests()
    fixture.setUp()
    try:
        refs = fixture.raw_step_kit().parent / 'refs'
        result = {name: gate.pixel_digest(gate.rgba(refs / (name + '.png')))
                  for name in ('raw', 'edit', 'composite', 'tone')}
        result['mask'] = gate.pixel_digest(gate.mask_reference(gate.rgba(refs / 'tone.png'),
                                                              [RAW_STEP_FIXTURE_REGION]))
        return result
    finally:
        fixture.doCleanups()


def maquette_compiler():
    from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
    from spec.art_identity.maquettes.blender.contract import digest
    paths = [f'spec/art_identity/maquettes/{name}/measurements.json' for name in MAQUETTES]
    paths.append('spec/art_identity/maquettes/gloam_stalker/r3/measurements.json')
    return {name: digest(compile_recipe(json.loads((ROOT / name).read_text()))) for name in paths}


def classical_audio():
    from tests.test_classical_soundtrack_pipeline import CONFIG
    from classical_soundtrack_pipeline.render import render_track
    with tempfile.TemporaryDirectory(prefix='python-audio-golden-') as temporary:
        report = render_track(CONFIG, Path(temporary))
        return {name: report['audio'][name] for name in ('ogg_sha256', 'flac_sha256')}


def tooltip_data():
    data = json.loads((ROOT / 'data/glossary.json').read_text())
    copy = json.loads((ROOT / 'spec/peer_benchmark/staged/tt-01/tooltips.json').read_text())
    return {'metadata': [{key: value for key, value in entry.items() if key != 'definition'} for entry in data],
            'unchanged': [entry for entry in data if entry['id'] in copy['unchanged_ids']]}


def rr49_submission():
    from godot_task_runner import infer_task_id
    fixture = ROOT / 'experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a'
    with tempfile.TemporaryDirectory(prefix='python-submission-golden-') as temporary:
        output = Path(temporary) / 'buffers.json'
        command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--task-id',
                   os.environ.get('LABYRINTH_TASK_ID') or infer_task_id(ROOT),
                   '--timeout', str(ENGINE_TIMEOUT_SECONDS), '--stream', '--', 'godot',
                   '--headless', '--path', '.', '--script', 'tests/rr49/submission_hashes.gd',
                   '--', '--input', str(fixture / 'cases.json'), '--output', str(output)]
        subprocess.run(command, cwd=ROOT, check=True, timeout=ENGINE_TIMEOUT_SECONDS + 5)
        return json.loads(output.read_text())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group', required=True,
                        choices=('raw-steps', 'maquette-compiler', 'classical-audio', 'rr49-submission', 'tooltip-data'))
    args = parser.parse_args(argv)
    functions = {'raw-steps': raw_steps, 'maquette-compiler': maquette_compiler,
                 'classical-audio': classical_audio, 'rr49-submission': rr49_submission, 'tooltip-data': tooltip_data}
    names = {'raw-steps': 'art_raw_steps.json', 'maquette-compiler': 'maquette_compiler.json',
             'classical-audio': 'classical_audio.json', 'rr49-submission': 'rr49_submission.json.gz', 'tooltip-data': 'glossary_metadata.json'}
    value = functions[args.group]()
    target = GOLDENS / names[args.group]
    target.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()
    if target.exists():
        old = target.read_bytes()
        previous = gzip.decompress(old) if target.suffix == '.gz' else old
        previous = (json.dumps(json.loads(previous), indent=2, sort_keys=True) + '\n').encode()
        for line in difflib.unified_diff(previous.decode().splitlines(), encoded.decode().splitlines(),
                                         fromfile='previous/' + target.name, tofile='current/' + target.name):
            print(line)
    target.write_bytes(gzip.compress(encoded, mtime=0) if target.suffix == '.gz' else encoded)
    print(f'UPDATED GOLDEN: {target.relative_to(ROOT)}; review the diff before accepting')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
