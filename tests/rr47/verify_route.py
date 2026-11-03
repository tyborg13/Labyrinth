"""Validate and optionally bind a fresh, native single-route regression fixture."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tests.rr46.verify_native import check_images, indices, PHASE_EPSILON

ROUTE = 'move_2_1_-1_1'


def verify(folder, source_root=ROOT):
    inventory_path = source_root / 'tests/rr46/native_inventory.json'
    inventory = json.loads(inventory_path.read_text())
    for name, digest in inventory['source_hashes'].items():
        if hashlib.sha256((source_root / name).read_bytes()).hexdigest() != digest:
            raise ValueError('Stale route source binding: ' + name)
    report = json.loads((folder / 'findings.json').read_text())
    if (report.get('native') is not True or report.get('scope') != 'rr47_back_route'
            or report.get('schema') != 4 or report.get('selected_routes') != [ROUTE]):
        raise ValueError('Not a complete native regression-route report')
    if report['inventory_sha256'] != hashlib.sha256(inventory_path.read_bytes()).hexdigest():
        raise ValueError('Route archive inventory hash differs')
    if report['errors'] or not report['calibration']['passed']:
        raise ValueError('Native route/calibration failures: ' + str(report['errors']))
    check_images(folder, report['calibration']['row'], report['primitives'])
    rows = report['captures']
    count = inventory['actors'][report['actor']]['move_frames']
    if [row['frame'] for row in rows] != indices(count, False):
        raise ValueError('Incomplete native regression-route cadence')
    for index, row in enumerate(rows):
        if (row['route_id'] != ROUTE or row['clip'] != 'move' or row['direction'] != [-1, 1]
                or row['terminal_absence'] or row['painted']['actor_pixels'] <= 0
                or row['painted']['errors'] or row['painted']['painted_errors']):
            raise ValueError('Missing/misordered actor on native regression route')
        if abs(row['phase'] - (row['frame'] + 1) / count) > PHASE_EPSILON:
            raise ValueError('Incorrect native route phase')
        endpoint = row['frame'] in (0, count - 1)
        if (row['frame_required'] != endpoint or row['evidence'] != (endpoint or index % 10 == 0)):
            raise ValueError('Incorrect native route evidence cadence')
        check_images(folder, row, report['primitives'])
    cost = report['cost']
    if not 0 < cost['elapsed_seconds'] <= 300 or not 0 < cost['bytes'] <= 250000000:
        raise ValueError('Route capture budget exceeded')
    # Bind every emitted frame, ID primitive, crop and metadata byte. The
    # manifest itself is excluded so its hash set remains stable on validation.
    hashes = {str(path.relative_to(folder)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(folder.rglob('*')) if path.is_file() and path.name != 'route_fixture.json'}
    return {'schema': 1, 'route': ROUTE, 'actor': report['actor'], 'board': report['board'],
            'inventory_sha256': report['inventory_sha256'], 'files': hashes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--source-root', type=Path, default=ROOT)
    parser.add_argument('--bind', action='store_true')
    args = parser.parse_args()
    binding = verify(args.folder, args.source_root)
    path = args.folder / 'route_fixture.json'
    if path.exists():
        if json.loads(path.read_text()) != binding:
            raise ValueError('Native regression fixture hashes differ')
    elif args.bind:
        path.write_text(json.dumps(binding, indent=2) + '\n')
    print('RR47 NATIVE ROUTE FIXTURE: PASS (' + str(len(binding['files'])) + ' SHA-256-bound files)')


if __name__ == '__main__':
    main()
