"""Storm Cantor's walk-01 port; never rebuild paint or unrelated action tracks."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT)]
from humanoid_cutout import walk_cadence, walk_proof

CASE = Path(__file__).parent
PRODUCTION = ROOT / 'assets/units/storm_cantor_cutout/humanoid_v2'
CREATURE = 'storm_cantor'
# Selected by unchanged front/rear reach gates; see walk03_reach.json.
WALK_STEPS_PER_TILE = 5
BASELINE = 'd5c39432a'


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')


def revise_director(path, steps=WALK_STEPS_PER_TILE):
    """Apply the cadence decision to the protected source's derived copy only."""
    data = json.loads(path.read_text())
    move = data[CREATURE]['clips']['move']
    original = copy.deepcopy(move)
    move['seconds'] = steps / walk_cadence.STEPS_PER_SECOND
    move['gait']['steps_per_tile'] = steps
    jolts = walk_cadence.retime_jolts(original, move)
    path.write_text(json.dumps(data, indent=1))
    return jolts


def stage_proofs(output):
    """Scope existing walk-01 probes without editing shared tools/other rigs.

    Keep all gate/assertion code intact. Only the rig inventory, proof labels
    and relative preloads change. Retain source hashes for the director.
    """
    output.mkdir(parents=True, exist_ok=True)
    toolkit = ROOT / 'tools/humanoid_cutout'
    paths = {name: output / name for name in
             ('walk_samples.gd', 'walk_turn_proof.gd', 'walk_turn_scene.gd', 'walk_capture.gd')}
    sources = {}
    for name, destination in paths.items():
        source = toolkit / name
        raw = source.read_text()
        sources[str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
        if name == 'walk_samples.gd':
            raw, count = re.subn(r'^const TYPES := .*$', 'const TYPES := ["storm_cantor"]', raw, flags=re.M)
            assert count == 1
        if name in ('walk_turn_proof.gd', 'walk_turn_scene.gd'):
            raw = raw.replace('ashen_reaver', CREATURE).replace('Reaver', 'Storm Cantor')
            raw = raw.replace('"raking_flame"', '"peal"')
        if name == 'walk_turn_proof.gd':
            # The Cantor prefers range three. Start six tiles away so the real
            # resolver uses the entire three-tile debug movement budget.
            raw = raw.replace('PROOF_ENEMY_TILE := Vector2i(6, 4)', 'PROOF_ENEMY_TILE := Vector2i(7, 4)')
            raw = raw.replace('PROOF_PLAYER_TILE := Vector2i(2, 4)', 'PROOF_PLAYER_TILE := Vector2i(1, 4)')
        raw = raw.replace('preload("walk_samples.gd")', 'preload(' + json.dumps(str(paths['walk_samples.gd'])) + ')')
        raw = raw.replace('preload("walk_turn_scene.gd")', 'preload(' + json.dumps(str(paths['walk_turn_scene.gd'])) + ')')
        raw = raw.replace('WALK-01', 'WALK-03')
        destination.write_text(raw)
    write(output / 'sources.json', sources)
    print('WALK-03 PROOF TOOLS: PASS (walk-01 assertions retained; Storm Cantor only)')


def apply_candidate(directory):
    data = json.loads((directory / (CREATURE + '.json')).read_text())
    source = directory / (CREATURE + '_director_motion.json')
    for folder in (CASE, PRODUCTION):
        (folder / 'director_motion.json').write_bytes(source.read_bytes())
        write(folder / 'compiled_motion.json', data)
    config = json.loads((CASE / 'cutout.json').read_text())
    config['clips']['move'] = data['clips']['move']
    write(CASE / 'cutout.json', config)
    print('WALK-03 APPLY: PASS (%d steps; %.9f s/tile)' %
          (data['clips']['move']['gait']['steps_per_tile'], data['clips']['move']['seconds']))


def byte_identity():
    """Compare serialized non-move arrays, protected paint, rest records/pins."""
    prefix = 'assets/units/storm_cantor_cutout/'
    checked = 0
    decoder = json.JSONDecoder()
    for folder in (CASE, PRODUCTION):
        path = folder / 'compiled_motion.json'
        original_raw = subprocess.check_output(['git', 'show', BASELINE + ':' + str(path.relative_to(ROOT))]).decode()
        raw = path.read_text()
        old, new = json.loads(original_raw), json.loads(raw)
        for view, clips in old['view_tracks'].items():
            # Exact slices include all array whitespace and serialized values.
            old_start = original_raw.index('"' + view + '":', original_raw.index('"view_tracks":'))
            new_start = raw.index('"' + view + '":', raw.index('"view_tracks":'))
            for clip in clips:
                if clip == 'move': continue
                arrays = []
                for text, start in ((original_raw, old_start), (raw, new_start)):
                    at = text.index('"' + clip + '":', start) + len(json.dumps(clip)) + 1
                    while text[at].isspace(): at += 1
                    _, end = decoder.raw_decode(text, at)
                    arrays.append(text[at:end])
                assert arrays[0] == arrays[1], (path, view, clip)
                assert old['clips'][clip] == new['clips'][clip]
                checked += 1
        assert new['projection']['rear']['forward'] == [-v for v in new['projection']['front']['forward']]
        assert new['view_held_drops'] == old['view_held_drops']
        assert new['budget_clamps'] == old['budget_clamps']
    old_pins = json.loads(subprocess.check_output(['git', 'show', BASELINE + ':tests/approved_asset_pins.json']))
    pins = json.loads((ROOT / 'tests/approved_asset_pins.json').read_text())
    pin_counts = {}
    for section in ('files', 'images'):
        owned = {k: v for k, v in old_pins[section].items() if k.startswith(prefix)}
        assert set(owned) <= set(pins[section]), section
        for name, value in owned.items():
            path = ROOT / name
            if section == 'files':
                raw = path.read_bytes()
                observed = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
                assert pins[section][name] == observed, name
                if path.suffix == '.png': assert observed == value, name
            else:
                assert pins[section][name] == value, name
        pin_counts[section] = len(owned)
    integration = json.loads(subprocess.check_output(['git', 'show', 'HEAD:tests/approved_asset_pins.json']))
    for section in ('files', 'images', 'registration', 'enemy_art'):
        assert {k: v for k, v in pins[section].items() if not k.startswith(prefix) and k != CREATURE} == {
            k: v for k, v in integration[section].items() if not k.startswith(prefix) and k != CREATURE}, section
    assert [r for r in pins['roster'] if r['actor'] != CREATURE] == [r for r in integration['roster'] if r['actor'] != CREATURE]
    for name in ('spec/assets/board_pixel_density/outputs.json',
                 'spec/peer_benchmark/staged/rr-56/motion_tracks.json',
                 'spec/peer_benchmark/staged/rr-56/front_body_underlay.png',
                 'spec/peer_benchmark/staged/rr-56/rear_body_underlay.png'):
        assert (ROOT / name).read_bytes() == subprocess.check_output(['git', 'show', 'HEAD:' + name]), name
    print('WALK-03 NON-MOVE BYTE IDENTITY: PASS (%d arrays; paint, rest records, held drops and clamps retained)' % checked)
    print('WALK-03 PRE-MERGE PINS: PASS (%d files; %d image records; unrelated integration pins retained)' %
          (pin_counts['files'], pin_counts['images']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage-proofs', type=Path)
    parser.add_argument('--candidate', type=int, choices=(4, 5, 6))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--gates', type=Path)
    parser.add_argument('--motion-dir', type=Path)
    parser.add_argument('--apply', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.stage_proofs: stage_proofs(args.stage_proofs.resolve())
    if args.candidate:
        record = walk_cadence.revision(CREATURE, args.candidate, args.output)
        write(args.output / 'cadence.json', record)
        print('WALK-03 CANDIDATE: ' + json.dumps(record))
    if args.apply: apply_candidate(args.apply)
    if args.check: byte_identity()
    if args.gates:
        walk_proof.TYPES = (CREATURE,)
        result = walk_proof.prove(args.gates, BASELINE, args.motion_dir, move_only=True)
        raise SystemExit(0 if result['ok'] else 1)
