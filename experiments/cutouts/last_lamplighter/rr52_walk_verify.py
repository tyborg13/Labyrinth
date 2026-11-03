"""Focused walk-02 contracts; explicit task proof, no shared fixture writes."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from rr52_build import ROOT, CASE, ASSETS, DIRECTOR, projection, VIEWS
from rr52_walk import CREATURE, STEPS_PER_TILE, authored, revision
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion

BASELINE = 'd924af0bf'


def git_bytes(path, ref=BASELINE):
    return subprocess.check_output(['git', 'show', ref + ':' + str(path.relative_to(ROOT))], cwd=ROOT)


def raw_tracks(text, view, clip):
    start = text.index('"view_tracks": {')
    start = text.index('"' + view + '": {', start)
    start = text.index('"' + clip + '": [', start)
    start = text.index('[', start)
    _, length = json.JSONDecoder().raw_decode(text[start:])
    return text[start:start + length].encode()


def verify(output, samples_path=None):
    errors, arrays, paint = [], 0, 0
    production = ASSETS / 'humanoid_v2'
    for path in (CASE / 'compiled_motion.json', production / 'compiled_motion.json'):
        original_text, current_text = git_bytes(path).decode(), path.read_text()
        original, current = json.loads(original_text), json.loads(current_text)
        for view in VIEWS:
            for clip in original['view_tracks'][view]:
                if clip == 'move': continue
                arrays += 1
                if raw_tracks(original_text, view, clip) != raw_tracks(current_text, view, clip):
                    errors.append(str(path.relative_to(ROOT)) + ': non-move bytes changed: ' + view + '/' + clip)
        for key in original:
            if key not in ('projection', 'director_sha256', 'view_tracks', 'clips') and original[key] != current[key]:
                errors.append('Retained motion policy changed: ' + key)
        for clip in original['clips']:
            if clip != 'move' and original['clips'][clip] != current['clips'][clip]:
                errors.append('Non-move metadata changed: ' + clip)
        if current['projection'] != {view: projection(view) for view in VIEWS}:
            errors.append('Source-builder projection differs')
    for path in ASSETS.rglob('*.png'):
        paint += 1
        if path.read_bytes() != git_bytes(path): errors.append('Paint changed: ' + str(path))
    for path in (DIRECTOR, CASE / 'director_motion.json'):
        if path.read_bytes() != git_bytes(path): errors.append('Protected source/rebake record changed: ' + str(path))
    density_path = ROOT / 'spec/assets/board_pixel_density/outputs.json'
    old_density, density = json.loads(git_bytes(density_path)), read_json(density_path)
    prefix = str(ASSETS.relative_to(ROOT)) + '/'
    if {k:v for k,v in old_density.items() if k.startswith(prefix)} != {k:v for k,v in density.items() if k.startswith(prefix)}:
        errors.append('Lamplighter rest rebake records changed')
    if density_path.read_bytes() != git_bytes(density_path, 'HEAD'):
        errors.append('Integration density records changed')
    current = read_json(production / 'compiled_motion.json')
    author, jolts = authored()
    if read_json(production / 'director_motion.json') != author: errors.append('Production director override differs')
    if current['director_sha256'] != digest(production / 'director_motion.json'): errors.append('Director provenance differs')
    if current['clips']['move']['gait']['steps_per_tile'] != STEPS_PER_TILE: errors.append('Unexpected step count')
    if current['clips']['move']['seconds'] != STEPS_PER_TILE / 12: errors.append('Not 12 steps per second')
    layouts = {view: dict(read_json(production / (view + '.json')), anatomy=read_json(CASE / 'anatomy.json')) for view in VIEWS}
    rebuilt, _, _ = revision(current, layouts, {view: projection(view) for view in VIEWS})
    if rebuilt != current: errors.append('Move recompile differs')
    bad = deepcopy(current['projection'])
    bad['rear']['forward'][1] *= -1
    with tempfile.TemporaryDirectory(prefix='walk-02-verify-') as directory:
        path = Path(directory) / 'director.json'; path.write_text(json.dumps(author))
        try:
            compile_motion(path, CREATURE, layouts, bad)
            errors.append('Compiler accepted the old zig-zag projection')
        except ValueError as error:
            if 'rear.forward' not in str(error): raise
    pins_path = ROOT / 'tests/approved_asset_pins.json'
    before, pins = json.loads(git_bytes(pins_path)), read_json(pins_path)
    prefix = str(ASSETS.relative_to(ROOT)) + '/'
    counts = {}
    for kind in ('files', 'images'):
        expected = {name for name in before[kind] if CREATURE in name}
        counts[kind] = len(expected)
        if not expected.issubset(pins[kind]): errors.append('Missing premerge ' + kind + ' pin')
        for name in expected:
            path = ROOT / name
            if kind == 'files':
                blob = path.read_bytes()
                value = hashlib.sha1(b'blob ' + str(len(blob)).encode() + b'\0' + blob).hexdigest()
                if pins[kind].get(name) != value: errors.append('Stale file pin: ' + name)
            else:
                from PIL import Image
                with Image.open(path) as image:
                    value = {'size': list(image.size), 'alpha_bounds': list(image.convert('RGBA').getchannel('A').getbbox() or ())}
                if pins[kind].get(name) != value: errors.append('Stale image pin: ' + name)
    head_pins = json.loads(git_bytes(pins_path, 'HEAD'))
    for kind in ('files', 'images'):
        if {k:v for k,v in head_pins[kind].items() if not k.startswith(prefix)} != {k:v for k,v in pins[kind].items() if not k.startswith(prefix)}:
            errors.append('Unrelated ' + kind + ' pins changed')
    integration = read_json(ASSETS / 'integration.json')
    if integration['director_sha256'] != current['director_sha256']: errors.append('Stale integration director hash')
    for name, sha in integration['files'].items():
        if digest(ASSETS / name) != sha: errors.append('Stale integration file: ' + name)
    held_views = {}
    if samples_path is not None:
        from rr52_gates import held
        samples = read_json(samples_path)
        if samples.get('compiled_sha256') != digest(CASE / 'compiled_motion.json'):
            errors.append('Stale held-item samples')
        for view in VIEWS:
            for clip, definition in current['clips'].items():
                rows = [r for r in samples['samples'] if r['view'] == view and r['clip'] == clip and r['kind'] == 'presented']
                if [r['frame'] for r in rows] != list(range(round(definition['seconds'] * 60))):
                    errors.append('Incomplete held-item frame inventory: ' + view + '/' + clip)
            held_views[view] = held(read_json(CASE / ('layouts/' + view + '.json')), current, samples)
            errors += held_views[view]['errors']
            print('WALK-02 HELD %s: %s (%d checks; max grip error %.9f px)' %
                  (view, 'PASS' if held_views[view]['ok'] else 'FAIL', held_views[view]['checks'], held_views[view]['max_grip_error_px']))
    result = {'ok': not errors, 'errors': errors, 'non_move_arrays_byte_identical': arrays,
              'paint_files_byte_identical': paint, 'premerge_pins': counts, 'retimed_channels': jolts,
              'steps': STEPS_PER_TILE, 'seconds': STEPS_PER_TILE / 12, 'held': held_views, 'native_pixels': False}
    write_json(output, result)
    print('WALK-02 FOCUSED CONTRACTS: %s (%d non-move arrays byte-identical; %d paint files retained; %d file / %d image pins current)' %
          ('FAIL' if errors else 'PASS', arrays, paint, counts['files'], counts['images']))
    for error in errors: print(error)
    return not errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--samples', type=Path)
    args = parser.parse_args()
    raise SystemExit(0 if verify(args.output, args.samples) else 1)
