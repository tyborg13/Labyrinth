"""walk-02: compile only the approved cadence change; retain the rest rebake.

The staged director file and its editable-case copy remain immutable. The
production director copy records the walk-02 overrides, as in walk-01.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile

from rr52_build import ROOT, CASE, ASSETS, DIRECTOR, VIEWS
from rr52_motion import clamp_limits
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.walk_cadence import retime_jolts, STEPS_PER_SECOND

CREATURE = 'last_lamplighter'
STEPS_PER_TILE = 4  # Both views pass every unchanged walk gate at four steps.


def authored(steps=STEPS_PER_TILE):
    source = read_json(DIRECTOR)
    move = source[CREATURE]['clips']['move']
    old_move = deepcopy(move)
    move['gait']['steps_per_tile'] = steps
    move['seconds'] = steps / STEPS_PER_SECOND
    jolts = retime_jolts(old_move, move)
    return source, jolts


def revision(original, layouts, projection, steps=STEPS_PER_TILE):
    """Keep every non-move compiled array, including recorded joint clamps."""
    author, jolts = authored(steps)
    with tempfile.TemporaryDirectory(prefix='walk-02-compile-') as temporary:
        source = Path(temporary) / 'director_motion.json'
        # Match the existing one-space director serialization.
        source.write_text(json.dumps(author, indent=1) + '\n')
        compiled = clamp_limits(compile_motion(source, CREATURE, layouts, projection))
    result = deepcopy(original)
    result['projection'] = deepcopy(projection)
    result['director_sha256'] = compiled['director_sha256']
    result['clips']['move'] = compiled['clips']['move']
    for view in VIEWS:
        result['view_tracks'][view]['move'] = compiled['view_tracks'][view]['move']
    return result, author, jolts


def candidate(steps, output):
    production = ASSETS / 'humanoid_v2'
    original = read_json(production / 'compiled_motion.json')
    projection = deepcopy(original['projection'])
    projection['rear']['forward'] = [-value for value in projection['front']['forward']]
    anatomy = read_json(CASE / 'anatomy.json')
    layouts = {view: dict(read_json(production / (view + '.json')), anatomy=anatomy) for view in VIEWS}
    result, author, jolts = revision(original, layouts, projection, steps)
    output.mkdir(parents=True, exist_ok=True)
    write_json(output / (CREATURE + '.json'), result)
    (output / (CREATURE + '_director_motion.json')).write_text(json.dumps(author, indent=1) + '\n')
    record = {'steps': steps, 'seconds': steps / STEPS_PER_SECOND,
              'frames_per_tile': round(steps / STEPS_PER_SECOND * 60), 'retimed_channels': jolts}
    write_json(output / 'cadence.json', record)
    print('WALK-02 CANDIDATE: PASS (%d steps; %.9f seconds; %d frames)' %
          (steps, record['seconds'], record['frames_per_tile']))
    return result, author


def install(output):
    result = read_json(output / (CREATURE + '.json'))
    assert result['clips']['move']['gait']['steps_per_tile'] == STEPS_PER_TILE
    source = output / (CREATURE + '_director_motion.json')
    assert hashlib.sha256(source.read_bytes()).hexdigest() == result['director_sha256']
    for target in (CASE / 'compiled_motion.json', ASSETS / 'humanoid_v2/compiled_motion.json'):
        previous = read_json(target)
        for view in VIEWS:
            for clip, tracks in previous['view_tracks'][view].items():
                if clip != 'move': assert tracks == result['view_tracks'][view][clip], (view, clip)
        write_json(target, result)
    (ASSETS / 'humanoid_v2/director_motion.json').write_bytes(source.read_bytes())
    config = read_json(CASE / 'cutout.json')
    config['clips']['move'] = result['clips']['move']
    write_json(CASE / 'cutout.json', config)
    integration = read_json(ASSETS / 'integration.json')
    integration['director_sha256'] = result['director_sha256']
    for name in integration['files']:
        integration['files'][name] = digest(ASSETS / name)
    write_json(ASSETS / 'integration.json', integration)
    print('WALK-02 INSTALL: PASS (move only; rest paintings retained)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--steps', type=int, choices=(4, 5, 6), default=STEPS_PER_TILE)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    candidate(args.steps, args.output)
    if args.install: install(args.output)
