"""walk-01 director feedback: reach candidates and 12-step/second revisions.

Explicit task tooling, not a suite guard. Only move tracks are recompiled;
retained non-move clamps and policies remain byte-identical on serialization.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess

from .compiler import compile_motion
from .gait import schedule
from .walk_proof import ROOT, TYPES

STEPS_PER_SECOND = 12


def baseline(path):
    return json.loads(subprocess.check_output(['git', 'show', 'HEAD:' + str(path.relative_to(ROOT))]))


def retime_jolts(old_move, move):
    """Recognize repeated full-landing pulses; keep all offsets in seconds."""
    old_contacts = [s['end'] for s in schedule(old_move['gait'])[1:-1]]
    contacts = [s['end'] for s in schedule(move['gait'])[1:-1]]
    changed = []
    for name, rows in old_move['keys'].items():
        if not isinstance(rows, list) or len(rows) != 2 + 3 * len(old_contacts): continue
        if rows[0] != [0, 0] or rows[-1] != [1, 0]: continue
        pulses = [rows[1 + 3 * i:4 + 3 * i] for i in range(len(old_contacts))]
        if any(abs(pulse[0][0] - contact) > 1e-9 or
               [row[1] for row in pulse] != [0, pulses[0][1][1], 0]
               for contact, pulse in zip(old_contacts, pulses)):
            continue
        shape = [(row[0] - old_contacts[0]) * old_move['seconds'] for row in pulses[0]]
        if any(any(abs((row[0] - contact) * old_move['seconds'] - offset) > 1e-9 or
                       row[1:] != template[1:]
                       for row, template, offset in zip(pulse, pulses[0], shape))
               for contact, pulse in zip(old_contacts, pulses)):
            continue
        retimed = [[0, 0]]
        for contact in contacts:
            retimed += [[contact + offset / move['seconds'], *row[1:]]
                        for offset, row in zip(shape, pulses[0])]
        retimed.append([1, 0])
        if any(a[0] >= b[0] for a, b in zip(retimed, retimed[1:])):
            raise ValueError('Landing jolt overlaps next contact or clip end: ' + name)
        move['keys'][name] = retimed
        changed.append({'channel': name, 'amplitude': pulses[0][1][1],
                        'offsets_seconds': shape, 'landings': contacts})
    return changed


def revision(creature, steps, output):
    production = ROOT / 'assets/units' / (creature + '_cutout') / 'humanoid_v2'
    original = baseline(production / 'compiled_motion.json')
    author = baseline(production / 'director_motion.json')
    old_move = copy.deepcopy(author[creature]['clips']['move'])
    move = author[creature]['clips']['move']
    move['seconds'] = (steps if 'gait' in move else 4) / STEPS_PER_SECOND
    if 'gait' in move: move['gait']['steps_per_tile'] = steps
    jolts = retime_jolts(old_move, move) if 'gait' in move else []
    output.mkdir(parents=True, exist_ok=True)
    source = output / (creature + '_director_motion.json')
    old_bytes = subprocess.check_output(['git', 'show', 'HEAD:' + str((production / 'director_motion.json').relative_to(ROOT))])
    indent = 1 if old_bytes.splitlines()[1].startswith(b' "') else 2
    source.write_text(json.dumps(author, indent=indent) + ('\n' if old_bytes.endswith(b'\n') else ''))
    integration = json.loads((production.parent / 'integration.json').read_text())
    anatomy = json.loads((ROOT / integration['case'] / 'anatomy.json').read_text())
    layouts = {view: dict(json.loads((production / (view + '.json')).read_text()), anatomy=anatomy)
               for view in original['view_tracks']}
    projection = json.loads((production / 'compiled_motion.json').read_text())['projection']
    compiled = compile_motion(source, creature, layouts, projection)
    result = copy.deepcopy(original)
    result['projection'] = projection
    result['director_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    result['clips']['move'] = compiled['clips']['move']
    for view in result['view_tracks']:
        result['view_tracks'][view]['move'] = compiled['view_tracks'][view]['move']
    (output / (creature + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    return {'creature': creature, 'steps': steps if 'gait' in move else 4,
            'seconds': move['seconds'], 'frames_per_tile': round(move['seconds'] * 60),
            'retimed_channels': jolts}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--steps', type=int, choices=(4, 5, 6), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    records = [revision(creature, args.steps, args.output) for creature in TYPES]
    (args.output / 'cadence.json').write_text(json.dumps(records, indent=2) + '\n')
    print('WALK-01 CADENCE CANDIDATES: PASS (%d rigs; %d steps; 12 steps/second)' % (len(records), args.steps))
