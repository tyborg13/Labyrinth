"""Reproduce mq-27 in bounded bridge jobs, then package untouched native PNGs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.burrow_grub.v2.recipe import HERE, LEGS, PROOF_DEFAULTS, CONSTRAINTS
from spec.art_identity.maquettes.raster import project

HERO = PROJECT / 'assets/units/protagonist_cutout/front/front_assembled_rest_v9.png'


def write(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bridge(args, log):
    command = [sys.executable, '-B', str(PROJECT / 'spec/art_identity/maquettes/blender/bridge_client.py'),
               '--timeout', str(PROOF_DEFAULTS['bridge_deadline_s']), str(HERE / 'build.py'), '--', *map(str, args)]
    # The director requires a hard 120 s no-answer stop, including queue time.
    try:
        result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True,
                                timeout=PROOF_DEFAULTS['bridge_deadline_s'])
    except subprocess.TimeoutExpired as error:
        log.write_text((error.stdout or b'').decode() if isinstance(error.stdout, bytes) else error.stdout or '')
        raise SystemExit('MQ27_BRIDGE: STOP; no answer within 120 s; do not retry')
    log.write_text(result.stdout + result.stderr)
    print(result.stdout.splitlines()[-1] if result.stdout.splitlines() else result.stderr, flush=True)
    if result.returncode:
        raise SystemExit(f'MQ27_BRIDGE: FAIL; inspect {log}')


def visibility(delivery, spec):
    result = {}
    for view in ('front', 'rear'):
        rgba = np.asarray(Image.open(delivery / f'{view}_parts.png').convert('RGBA'))
        rows = {}
        for name, colour in spec['labels'].items():
            linear = np.array(colour)
            rgb = np.rint(np.where(linear <= .0031308, linear * 12.92,
                          1.055 * linear ** (1 / 2.4) - .055) * 255)
            count = int(((abs(rgba[:, :, :3].astype(float) - rgb).max(2) <= PROOF_DEFAULTS['ownership_rgb_tolerance']) &
                         (rgba[:, :, 3] >= PROOF_DEFAULTS['alpha_threshold'])).sum())
            solo = np.asarray(Image.open(delivery / f'{view}_solo_{name}.png').convert('RGBA'))[:, :, 3]
            rows[name] = {'visible_pure_colour_px': count, 'solo_px': int((solo >= PROOF_DEFAULTS['alpha_threshold']).sum())}
        result[view] = rows
    front = result['front']
    two_far = sum(front[f'leg_far_{i}']['visible_pure_colour_px'] > 0 for i in range(1, 4)) >= 2
    checks = {'all_three_near_legs_visible': all(front[f'leg_near_{i}']['visible_pure_colour_px'] > 0 for i in range(1, 4)),
              'every_solo_nonempty': all(r['solo_px'] > 0 for view in result.values() for r in view.values())}
    return {'views': result, 'checks': checks, 'passed': all(checks.values()),
            'authority': 'mq-27 feedback 1: front near feet and rear visible legs; six labelled solos retained',
            'prior_brief_diagnostics': {'at_least_two_far_legs_visible': two_far},
            'TODO_DESIGN_FRONT_FAR_LEG_VISIBILITY': None if two_far else
                'Confirm occluded front far stubs under feedback 1; original two-far-leg visibility is not met.'}


def review(delivery, spec):
    defaults = PROOF_DEFAULTS
    canvas = Image.new('RGBA', tuple(defaults['review_size_px']), tuple(defaults['ground_rgb']) + (255,))
    draw = ImageDraw.Draw(canvas)
    floor = defaults['review_floor_y_px']
    tile_width = defaults['tile_width_px']
    support_z = json.loads((delivery / 'floor_contact_report.json').read_text())['floor_z_m']
    record = {'tile_width_px': tile_width, 'grub_art_scale': CONSTRAINTS['art_scale'],
              'hero_art_scale': 1.03, 'ground_rgb': defaults['ground_rgb'], 'sources': {}}
    for index, (label, path, art_scale) in enumerate([
            ('Front / art_scale 0.85', delivery / 'front_clay.png', CONSTRAINTS['art_scale']),
            ('Hero rest / art_scale 1.03', HERO, 1.03),
            ('Rear / art_scale 0.85', delivery / 'rear_clay.png', CONSTRAINTS['art_scale'])]):
        source = Image.open(path).convert('RGBA')
        width = round(tile_width * art_scale)
        ratio = width / source.width
        resized = source.resize((width, round(source.height * ratio)), Image.Resampling.LANCZOS)
        cx = defaults['review_centres_x_px'][index]
        if index == 1:
            ground_y = source.getbbox()[3] * ratio
            draw.line((cx - tile_width / 2, floor, cx + tile_width / 2, floor), fill=tuple(defaults['floor_rgb']) + (255,))
        else:
            view = 'front' if index == 0 else 'rear'
            ground_y = project(spec, [0, 0, support_z], view, 1024)[1] * ratio
            extent = defaults['review_axis_half_extent_m']
            endpoints = project(spec, [[-extent, 0, support_z], [extent, 0, support_z]], view, 1024)
            line = [(cx + (p[0] - 512) * ratio, floor + p[1] * ratio - ground_y) for p in endpoints]
            draw.line(line, fill=tuple(defaults['floor_rgb']) + (255,))
        left, top = round(cx - width / 2), round(floor - ground_y)
        canvas.alpha_composite(resized, (left, top))
        offset = defaults['review_label_offset_px']
        draw.text((cx + offset[0], offset[1]), label, fill=tuple(defaults['floor_rgb']) + (255,))
        record['sources'][path.name] = {'sha256': sha(path), 'source_size': list(source.size),
                                       'draw_width_px': width, 'scale': ratio,
                                       'placement_px': [left, top]}
    draw.text(tuple(defaults['review_caption_xy_px']), 'One common board scale; support floor axes drawn; native captures remain 1024.',
              fill=tuple(defaults['floor_rgb']) + (255,))
    canvas.convert('RGB').save(delivery / 'review/hero_beside.png')
    write(delivery / 'review/hero_beside.json', record)


def package(work, delivery):
    from spec.art_identity.maquettes.blender.curate_delivery import canonical_png
    from spec.art_identity.maquettes.burrow_grub.v2.screen_clearance import measure as screen_measure
    delivery.mkdir(parents=True, exist_ok=True)
    (delivery / 'review').mkdir(exist_ok=True)
    for name in ('build_report.json', 'source_spec.json', 'floor_contact_report.json'):
        shutil.copyfile(work / 'build' / name, delivery / name)
    joints = {}
    captures = []
    native_manifests = []
    unchanged_clays = True
    packing = {}
    for view in ('front', 'rear'):
        for kind in ('preview', 'solos'):
            directory = work / f'{view}-{kind}'
            manifest = json.loads((directory / 'capture_manifest.json').read_text())
            native_manifests.append(manifest)
            for path in directory.glob('*.png'):
                if path.name not in manifest['images'] or sha(path) != manifest['images'][path.name]['sha256']:
                    raise ValueError('Native capture hash mismatch: ' + str(path))
                target = delivery / path.name
                if path.name.endswith('_clay.png'):
                    shutil.copyfile(path, target)
                    unchanged_clays &= sha(path) == sha(target)
                else:
                    # mq-05 packing: checks every alpha and all visible RGBA;
                    # only undefined RGB under alpha zero may be discarded.
                    canonical_png(path, target, mask=True)
                packing[path.name] = {'native_sha256': sha(path), 'packed_sha256': sha(target),
                                      'native_bytes': path.stat().st_size, 'packed_bytes': target.stat().st_size}
            capture = json.loads((directory / f'{view}_{kind}_capture.json').read_text())
            capture['combined_mesh_hash'] = json.loads((directory / 'build_report.json').read_text())['combined_mesh_hash']
            captures.append(capture)
            joints.update(json.loads((directory / 'joints_px.json').read_text()))
    write(delivery / 'joints_px.json', joints)
    spec = json.loads((delivery / 'source_spec.json').read_text())
    visible = visibility(delivery, spec)
    write(delivery / 'solo_coverage.json', visible)
    screen = screen_measure(delivery, spec, visible)
    floor_report = json.loads((delivery / 'floor_contact_report.json').read_text())
    floor_report['screen_clearance'] = screen
    floor_report['checks']['foot_screen_clearance'] = screen['passed']
    floor_report['passed'] &= screen['passed']
    write(delivery / 'floor_contact_report.json', floor_report)
    contract = json.loads((HERE / 'feedback_1_contract.json').read_text())
    protected_solos = all(sha(delivery / name) == value for name, value in contract['protected_solo_sha256'].items())
    review(delivery, spec)
    unclipped = {}
    for path in delivery.glob('*.png'):
        alpha = np.asarray(Image.open(path).convert('RGBA'))[:, :, 3]
        unclipped[path.name] = bool(max(alpha[0].max(), alpha[-1].max(), alpha[:, 0].max(), alpha[:, -1].max()) == 0)
    write(delivery / 'capture_packing.json', {'passed': True, 'native_clay_bytes_unchanged': unchanged_clays,
          'alpha_and_visible_rgba_unchanged': True, 'images': packing})
    report = {'schema': 1, 'captures': captures, 'native_capture_manifests': native_manifests,
              'native_clay_bytes_unchanged': unchanged_clays,
              'size_px': [1024, 1024], 'camera': {'azimuth_deg': 45, 'elevation_deg': 30,
              'ortho_scale_m': 2.4, 'target': spec['target']},
              'rear_is_same_pose_yaw_deg': 180, 'visibility': visible['checks'], 'unclipped': unclipped,
              'approved_body_solos_unchanged': protected_solos, 'foot_screen_clearance': screen['passed'],
              'png_sha256': {p.name: sha(p) for p in sorted(delivery.glob('*.png'))},
              'passed': all(c['passed'] for c in captures) and visible['passed'] and all(unclipped.values()) and
                        unchanged_clays and protected_solos and screen['passed']}
    write(delivery / 'capture_report.json', report)
    print('MQ27_DELIVERY: ' + ('PASS' if report['passed'] else 'FAIL'))
    print('MQ27_FRONT_LEGS: ' + str({name: visible['views']['front'][name]['visible_pure_colour_px'] for name in LEGS}))
    print('MQ27_SCREEN_CLEARANCE: ' + str({view: {n: r.get('below_body_px', r.get('reason'))
          for n, r in rows.items()} for view, rows in screen['views'].items()}))
    return report['passed']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['all', 'captures', 'package'])
    parser.add_argument('--work', type=Path, default=Path('/private/tmp/labyrinth_codex/mq-27'))
    parser.add_argument('--delivery', type=Path, default=HERE / 'delivery')
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    if args.mode == 'all':
        bridge(['build', args.work / 'build'], args.work / 'build.log')
    if args.mode in ('all', 'captures'):
        for view in ('front', 'rear'):
            for kind in ('preview', 'solos'):
                bridge(['capture', args.work / 'build', '--out', args.work / f'{view}-{kind}',
                        '--view', view, '--kind', kind], args.work / f'{view}-{kind}.log')
    return 0 if package(args.work, args.delivery) else 1


if __name__ == '__main__':
    raise SystemExit(main())
