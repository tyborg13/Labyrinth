"""Fail-closed verification of native paint, route coverage and sampling."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops

if __package__:
    from .board_coordinates import compare_primitives
else:
    from board_coordinates import compare_primitives

ROOT = Path(__file__).resolve().parents[2]
INVENTORY = Path(__file__).with_name('native_inventory.json')
RIGS = ('hoarfrost_seer', 'arc_thrall', 'glacial_mirror', 'briar_weaver',
        'hollow_mimic', 'slag_mortar', 'gale_herald', 'gloam_stalker',
        'frostglass_lancer', 'chainbound_gaoler')
BOARDS = {'fire_t1_r6', 'earth_t3_r7'}
DIRECTIONS = {(1, 0), (0, 1), (-1, 0), (0, -1),
              (1, 1), (-1, -1), (1, -1), (-1, 1)}
CATEGORIES = ('floor_front', 'floor_behind', 'wall_front', 'wall_behind',
              'prop_front', 'prop_behind')
EXEMPT_REASONS = {'no_kind_on_board', 'no_legal_ground_side', 'no_projected_bounds_on_side', 'production_culls_kind'}
KIND_PRIORITY = {'floor': 0, 'wall': 1, 'prop': 2, 'actor': 3}
PHASE_EPSILON = 1e-9
COST_REPORT_BYTE_TOLERANCE = 1024
ACTOR_ID_COLOR_MULTIPLIER = 7919
PROP_BEHIND_WITNESS = ('move_3_3_-1_1', [3, 3], [2, 4])
CORNER_WITNESS = ('move_3_5_-1_1', [3, 5], [2, 6])
LOGICAL_SIZE = (1920, 1080)


def load_inventory(path=INVENTORY, *, root=ROOT):
    inventory = json.loads(path.read_text())
    if inventory['schema'] != 3:
        raise ValueError('Unsupported inventory schema')
    if set(inventory['boards']) != BOARDS or set(inventory['actors']) != set(RIGS):
        raise ValueError('Inventory must contain exactly the director 20-job scope')
    if inventory.get('sampling') != {'move_stride': 2, 'move_midpoint_radius_frames': 1, 'death_stride': 1, 'retain_every': 10,
                                     'max_seconds': 300, 'max_bytes': 250000000}:
        raise ValueError('Incorrect final sampling/budget contract')
    for name, digest in inventory['source_hashes'].items():
        art = name.startswith('assets/') and Path(name).suffix in ('.png', '.json', '.res', '.tres')
        provenance = name.startswith('spec/art_identity/') and Path(name).name in ('registry.json', 'provenance.json')
        if (art or provenance) and hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
            raise ValueError('Stale independent art inventory: ' + name)
    for board in inventory['boards'].values():
        for name, start, end in (PROP_BEHIND_WITNESS, CORNER_WITNESS):
            witness = board['routes'].get(name, {})
            if not witness.get('mandatory') or witness.get('from') != start or witness.get('to') != end:
                raise ValueError('Missing legal pillar overlap witness: ' + name)
        mandatory = [route for route in board['routes'].values() if route['mandatory']]
        if {route['clip'] for route in mandatory} != {'move', 'keep_distance', 'death'}:
            raise ValueError('Inventory omits a required clip')
        if {tuple(route['direction']) for route in mandatory if route['clip'] == 'move'} != DIRECTIONS:
            raise ValueError('Inventory omits a required move direction')
    return inventory


def complete(timing, phase):
    end = timing['clip_seconds'] + timing['dissolve_seconds']
    return end > 0 and phase * end >= end


def indices(count, death):
    return list(range(count)) if death else sorted(set(range(0, count, 2)) | {count - 1}
                                                  | {f for f in range(count) if abs(f + 1 - count * 0.5) <= 1})


def order_key(layer):
    return (layer.get('plane', 1), layer['ground_y'], layer['ground_x'],
            layer.get('tie_rank', KIND_PRIORITY[layer['kind']]), layer['id'])


def verify(reports, inventory=None, expected_jobs=None):
    inventory = load_inventory() if inventory is None else inventory
    jobs = set(expected_jobs or ((board, actor) for board in inventory['boards'] for actor in inventory['actors']))
    errors, seen_jobs = [], set()
    frames = 0
    board_origins = []
    overlaps = dict.fromkeys(CATEGORIES, 0)
    for report in reports:
        job = (report.get('board'), report.get('actor'))
        if report.get('schema') != 4 or report.get('native') is not True:
            errors.append('Non-native or obsolete proof schema')
        if job not in jobs or job in seen_jobs:
            errors.append(str(job) + ': unknown or duplicate job')
            continue
        seen_jobs.add(job)
        board, actor = job
        board_contract = inventory['boards'][board]
        actor_contract = inventory['actors'][actor]
        requirements = board_contract['requirements'][actor]
        try:
            origin = compare_primitives(report.get('primitives', []), board_contract['drawn_primitives'])
            board_origins.append(dict(board=board, actor=actor, **origin))
        except (KeyError, TypeError, ValueError) as error:
            errors.append(str(job) + ': ' + str(error))
        if report.get('requirements') != requirements:
            errors.append(str(job) + ': overlap requirements/reasons differ from independent inventory')
        for category, fact in requirements.items():
            if fact['required'] and fact['reason']:
                errors.append(str(job) + ': required class cannot have an exemption')
            if not fact['required'] and fact['reason'] not in EXEMPT_REASONS:
                errors.append(str(job) + ': unlisted exemption: ' + category)
        errors.extend(report.get('errors', []))
        cost = report.get('cost', {})
        if not 0 < cost.get('elapsed_seconds', 0) <= 300 or not 0 < cost.get('bytes', 0) <= 250000000:
            errors.append(str(job) + ': absent/exceeded time or storage budget')
        calibration = report.get('calibration', {})
        control = calibration.get('row', {})
        if (not calibration.get('passed') or control.get('painted', {}).get('painted_errors') != 0
                or control.get('painted', {}).get('actor_pixels', 0) <= 0
                or control.get('painted', {}).get('errors')
                or any(v['overlap_pixels'] for v in control.get('painted', {}).get('occluders', {}).values())):
            errors.append(str(job) + ': actor-alone ID calibration failed/missing')
        if (not control.get('evidence') or not control.get('frame_required')
                or not control.get('frame_file') or control.get('composite_order') != ['actor']):
            errors.append(str(job) + ': missing actor-alone calibration evidence')
        selected = report.get('selected_routes', [])
        if len(set(selected)) != len(selected):
            errors.append(str(job) + ': duplicate selected route')
        mandatory = {key for key, route in board_contract['routes'].items() if route['mandatory']}
        if not mandatory.issubset(selected):
            errors.append(str(job) + ': missing mandatory move/retreat/death route')
        rows_by_route = defaultdict(list)
        job_overlaps = dict.fromkeys(CATEGORIES, 0)
        frame_files = set()
        for index, row in enumerate(report.get('captures', [])):
            identity = (board, actor, row.get('route_id'), row.get('frame'))
            rows_by_route[row.get('route_id')].append(row)
            frames += 1
            phase = row.get('phase', -1)
            death = row.get('clip') == 'death'
            count = actor_contract['death_frames' if death else 'move_frames']
            terminal = death and complete(actor_contract['death_timing'], phase)
            if row.get('terminal_absence') != terminal:
                errors.append(str(identity) + ': absence permitted before authored dissolve completion')
            if 'primitives' in report:
                layers = list(report['primitives']) + [{'id': 'actor', 'kind': 'actor', 'plane': 1,
                          'tie_rank': 4, 'ground_x': row['actor_ground'][0], 'ground_y': row['actor_ground'][1]}]
                if row.get('composite_order') != [layer['id'] for layer in sorted(layers, key=order_key)]:
                    errors.append(str(identity) + ': incorrect independent composition order')
            painted = row['painted']
            failed = bool(painted.get('errors') or painted.get('painted_errors'))
            if failed:
                errors.append(str(identity) + ': ID mismatch')
            first_last = (row['frame'] in (0, count - 1)
                          or (not death and abs(row['frame'] + 1 - count * 0.5) <= 1))
            frame_required = first_last or failed
            evidence = frame_required or index % 10 == 0
            if bool(row.get('frame_required')) != frame_required or bool(row.get('evidence')) != evidence:
                errors.append(str(identity) + ': incorrect evidence retention cadence')
            if frame_required and not row.get('frame_file'):
                errors.append(str(identity) + ': empty frame_file on first/last/midpoint/failing sample')
            if row.get('frame_file'):
                if row['frame_file'] in frame_files:
                    errors.append(str(identity) + ': reused full frame')
                frame_files.add(row['frame_file'])
            if evidence and any(not row.get(field) for field in ('crop', 'actual_id', 'expected_id', 'actor_mask')):
                errors.append(str(identity) + ': missing retained colour/ID evidence')
            if tuple(row.get('capture_size', ())) != LOGICAL_SIZE:
                errors.append(str(identity) + ': incorrect full-frame resolution')
            if painted['actor_pixels'] == 0 and not terminal:
                errors.append(str(identity) + ': early disappearance / empty actor crop')
            if painted['actor_pixels'] > 0 and terminal:
                errors.append(str(identity) + ': actor remains after dissolve completion')
            if death:
                clock = row.get('clock', {})
                if (clock.get('authored') != actor_contract['death_timing']
                        or clock.get('scaled') != actor_contract['scaled_death_timing']
                        or clock.get('progress') != phase):
                    errors.append(str(identity) + ': incorrect authored/scaled death clock')
                scaled = actor_contract['scaled_death_timing']
                expected_dissolve = min(1, max(0, (phase * scaled['total_seconds'] - scaled['clip_seconds']) / scaled['dissolve_seconds'])) if scaled['dissolve_seconds'] else phase
                expected_clip = min(1, phase * scaled['total_seconds'] / scaled['clip_seconds'])
                if abs(clock.get('clip_phase', -1) - expected_clip) > PHASE_EPSILON:
                    errors.append(str(identity) + ': incorrect clip clock phase')
                for key, expected_value in (
                        ('scaled_elapsed_seconds', phase * scaled['total_seconds']),
                        ('authored_elapsed_seconds', phase * sum(actor_contract['death_timing'].values())),
                        ('presentation_elapsed_seconds', row['frame'] * int(scaled['frame_seconds'] * 1000000 + 0.5) / 1000000),
                        ('hold_seconds', count * int(scaled['frame_seconds'] * 1000000 + 0.5) / 1000000)):
                    if abs(clock.get(key, -1) - expected_value) > PHASE_EPSILON:
                        errors.append(str(identity) + ': incorrect death elapsed clock: ' + key)
                if abs(clock.get('dissolve_phase', -1) - expected_dissolve) > PHASE_EPSILON:
                    errors.append(str(identity) + ': incorrect dissolve clock phase')
            if set(painted.get('occluders', {})) != set(CATEGORIES):
                errors.append(str(identity) + ': missing occluder classes')
            for category, result in painted.get('occluders', {}).items():
                if category not in job_overlaps:
                    errors.append(str(identity) + ': unknown occluder class')
                    continue
                job_overlaps[category] += result['overlap_pixels']
                if result.get('errors', 0):
                    errors.append(str(identity) + ': ID occluder mismatch')
        if set(rows_by_route) != set(selected):
            errors.append(str(job) + ': selected/captured route sets differ')
        for route_id, rows in rows_by_route.items():
            route = board_contract['routes'].get(route_id)
            if route is None:
                errors.append(str(job) + ': unknown route ' + str(route_id))
                continue
            death = route['clip'] == 'death'
            count = actor_contract['death_frames' if death else 'move_frames']
            if sorted(row['frame'] for row in rows) != indices(count, death):
                errors.append(f'{job}/{route_id}: incomplete frame indices / sampling stride')
            for row in rows:
                phase = row['frame'] / (count - 1) if death else (row['frame'] + 1) / count
                if row['clip'] != route['clip'] or tuple(row['direction']) != tuple(route['direction']):
                    errors.append(f'{job}/{route_id}: route/direction mismatch')
                if abs(row['phase'] - phase) > PHASE_EPSILON:
                    errors.append(f'{job}/{route_id}: authored frame phase mismatch')
            if not any(row['painted']['actor_pixels'] > 0 for row in rows):
                errors.append(f'{job}/{route_id}: no painted actor')
        for category, fact in requirements.items():
            if fact['required'] and job_overlaps[category] <= 0:
                errors.append(str(job) + ': zero required painted overlap: ' + category)
            overlaps[category] += job_overlaps[category]
    for job in jobs - seen_jobs:
        errors.append(str(job) + ': missing native job')
    return {'errors': errors, 'after_frames': frames, 'jobs': len(seen_jobs),
            'occluder_overlap_pixels': overlaps, 'board_origins': board_origins}


def encoded_actor(mask):
    code = ACTOR_ID_COLOR_MULTIPLIER  # ACTOR_CODE=1, matches ID encoding, independent of paint colour.
    image = Image.new('RGBA', mask.size, (code & 255, (code >> 8) & 255, (code >> 16) & 255, 255))
    image.putalpha(mask.point(lambda value: 255 if value else 0))
    return image


def check_images(folder, row, primitives=None):
    if row.get('frame_required') and not row.get('frame_file'):
        raise ValueError('Empty frame_file on required full frame')
    if row.get('frame_file'):
        with Image.open(folder / row['frame_file']) as image:
            if image.size != LOGICAL_SIZE:
                raise ValueError('Incorrect full-frame resolution: ' + row['frame_file'])
    if not row.get('evidence'):
        return
    for field in ('crop', 'actual_id', 'expected_id', 'actor_mask'):
        if not row.get(field):
            raise ValueError('Missing retained ID evidence: ' + field)
    with Image.open(folder / row['actor_mask']) as image:
        own = image.convert('RGBA').getchannel('A')
    if sum(own.histogram()[1:]) != row['painted']['actor_pixels']:
        raise ValueError('Saved actor mask and recorded painted pixel count differ')
    if not row['terminal_absence'] and own.getbbox() is None:
        raise ValueError('Empty actor mask before dissolve completion')
    if row['terminal_absence'] and own.getbbox() is not None:
        raise ValueError('Actor paint remains at authored dissolve completion')
    with Image.open(folder / row['actual_id']) as image:
        actual = image.convert('RGBA')
    with Image.open(folder / row['expected_id']) as image:
        expected = image.convert('RGBA')
    with Image.open(folder / row['crop']) as image:
        if image.size != own.size:
            raise ValueError('Colour crop dimensions differ from ID crop')
    if actual.size != expected.size or actual.size != own.size:
        raise ValueError('ID/reference/mask dimensions differ')
    delta = ImageChops.difference(actual, expected)
    channels = delta.split()
    mismatch = channels[0]
    for channel in channels[1:]:
        mismatch = ImageChops.lighter(mismatch, channel)
    if not row['terminal_absence']:
        mismatch = ImageChops.multiply(mismatch, own.point(lambda value: 255 if value else 0))
    if mismatch.getbbox():
        raise ValueError('Saved ownership IDs differ from independent composite')
    if primitives is not None:
        layers = [] if row.get('calibration') else list(primitives)
        layers.append({'id': 'actor', 'kind': 'actor', 'plane': 1, 'tie_rank': 4,
                       'ground_x': row['actor_ground'][0], 'ground_y': row['actor_ground'][1]})
        layers.sort(key=order_key)
        if row['composite_order'] != [layer['id'] for layer in layers]:
            raise ValueError('Composite order differs from independent ground-depth rule')
        recomposed = Image.new('RGBA', actual.size)
        origin = row['crop_rect'][:2]
        for layer in layers:
            if layer['id'] == 'actor':
                recomposed.alpha_composite(encoded_actor(own))
            else:
                with Image.open(folder / layer['image']) as image:
                    recomposed.alpha_composite(image.convert('RGBA'),
                                              (layer['offset'][0] - origin[0], layer['offset'][1] - origin[1]))
        if any(channel.getbbox() for channel in ImageChops.difference(recomposed, expected).split()):
            raise ValueError('Expected ID map differs from isolated primitive reconstruction')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--inventory', type=Path, default=INVENTORY)
    parser.add_argument('--result-file', type=Path, help='Write verification results and reconstructed per-job origins; never modifies captures.')
    args = parser.parse_args()
    if args.result_file and args.result_file.resolve().is_relative_to(args.archive.resolve()):
        parser.error('--result-file must be outside the captured archive')
    inventory = load_inventory(args.inventory)
    digest = hashlib.sha256(args.inventory.read_bytes()).hexdigest()
    reports = []
    for path in sorted(args.archive.rglob('findings.json')):
        report = json.loads(path.read_text())
        if report.get('inventory_sha256') != digest:
            raise ValueError('Archive is not bound to the current independent inventory')
        reports.append(report)
        measured_bytes = sum(file.stat().st_size for file in path.parent.rglob('*') if file.is_file())
        if measured_bytes > 250000000:
            raise ValueError('Archive exceeds 250 MB measured storage budget')
        if abs(measured_bytes - report.get('cost', {}).get('bytes', 0)) > COST_REPORT_BYTE_TOLERANCE:
            raise ValueError('Recorded storage cost differs from actual archive')
        check_images(path.parent, report.get('calibration', {}).get('row', {}), report.get('primitives', []))
        for row in report.get('captures', []):
            check_images(path.parent, row, report.get('primitives', []))
    result = verify(reports, inventory)
    result['inventory_sha256'] = digest
    if args.result_file:
        args.result_file.parent.mkdir(parents=True, exist_ok=True)
        args.result_file.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    print('RR46 NATIVE ARCHIVE: ' + ('FAIL' if result['errors'] else 'PASS'))
    return bool(result['errors'])


if __name__ == '__main__':
    raise SystemExit(main())
