"""Signed-bone, stepped pixel, glow, dark-slab, stray and native tie gates."""
import argparse
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from rr17_contract import *
from rr17_build import write, PRODUCTION
from maquette_motion import pixels, silhouette, native_ties
from maquette_motion import material_palette
from maquette_motion.gates import unpack, bindings_match


def coverage(report, field='samples'):
    errors = []
    author = read(DIRECTOR / 'motion_tracks.json')['storm_capacitor']['clips']
    for view in VIEWS:
        for clip, item in author.items():
            selected = [r for r in report[field] if r['view'] == view and r['clip'] == clip]
            if field == 'samples':
                count = round(item['seconds'] * 60)
                if sorted(r['frame'] for r in selected) != list(range(count)):
                    errors.append(f'{view}/{clip}: missing/duplicate presented frames')
            else:
                phases = {0, 1, *([item['contact']] if 'contact' in item else [])}
                for rows in item['keys'].values():
                    phases.update(r[0] for r in rows)
                    phases.update((a[0] + b[0]) / 2 for a, b in zip(rows, rows[1:]))
                if any(not any(abs(r['phase'] - at) < 1e-8 for r in selected) for at in phases):
                    errors.append(f'{view}/{clip}: missing authored key/midpoint/contact')
    return errors


def asset_errors():
    errors = []
    integration = read(CASE / 'integration.json')
    production = read(PRODUCTION / 'integration.json')
    if any(production.get(key) != value for key, value in integration.items()): errors.append('Production integration declarations differ from case')
    for path, expected in read(CASE / 'protected_inputs.json').items():
        if digest(ROOT / path) != expected: errors.append('Protected input changed: ' + path)
    for source, target in [('motion_tracks.json', 'director_motion.json'), ('cap_mask.png', 'source/cap_mask.png'), ('vent_fill.png', 'source/vent_fill.png')]:
        if (DIRECTOR / source).read_bytes() != (CASE / target).read_bytes(): errors.append('Protected copy changed: ' + target)
    paints = expected_paint()
    for view in VIEWS:
        layout = read(CASE / f'layouts/{view}.json')
        expected_joints = {'root': {'parent': None, 'position': [0, 0]}, 'column': {'parent': 'root', 'position': [0, 0]}, 'cap': {'parent': 'column', 'position': [131, 75]}}
        if layout['joints'] != expected_joints: errors.append(view + ': hierarchy/pivot differs')
        rest = Image.new('RGBA', (255, 255))
        for part in layout['parts']:
            image = Image.open(CASE / part['file']).convert('RGBA')
            box = paints[part['name']].getbbox()
            expected = paints[part['name']].crop(box)
            if part['offset'] != list(box[:2]) or not np.array_equal(image, expected): errors.append(view + '/' + part['name'] + ': partition differs')
            rest.alpha_composite(image, tuple(part['offset']))
        if not np.array_equal(rest, Image.open(PAINTING).convert('RGBA')): errors.append(view + ': rest identity differs')
        column = paints['column'].crop(paints['column'].getbbox())
        for level in range(-2, 3):
            expected = expected_glow(column, level)
            if not np.array_equal(Image.open(CASE / layout['glow_textures'][str(level)]).convert('RGBA'), expected):
                errors.append(f'{view}: glow {level} changes arc/non-arc/alpha pixels incorrectly')
    return errors


def small_components(image):
    return [size for _, size in silhouette.components(np.asarray(image)[..., 3] > 0)[1][1:] if size <= 8]


def dark_slab_errors(actual, expected, exempt=None):
    # rr-05's 3x3 derived-dark block rule. Approved painted shadows and the
    # table's dead arcs retain their provenance; only the vent is exempt.
    rules = material_palette.rules(CASE, 'front')
    dark = material_palette.outline_class(actual, rules) & pixels.changed(actual, expected)
    if exempt is not None: dark &= ~exempt
    blocks = np.ones((dark.shape[0] - 2, dark.shape[1] - 2), dtype=bool)
    for y in range(3):
        for x in range(3): blocks &= dark[y:y + blocks.shape[0], x:x + blocks.shape[1]]
    return ['new derived dark slab outside vent fill'] if blocks.any() else []


def motion_errors(report):
    errors = coverage(report, 'authored')
    for row in report['authored']:
        expected = bones(row['clip'], row['phase'], row['view'])
        for name in expected:
            for space in ('local', 'global'):
                if not np.allclose(unpack(row['bones'][name][space]), expected[name][space], atol=TOLERANCE, rtol=0):
                    errors.append(f'{row["view"]}/{row["clip"]}/{row["phase"]}/{name}: signed {space} motion differs')
    return errors


def native_contacts(capture, native):
    errors = []
    records = capture.get('contacts', [])
    paints = expected_paint()
    for view in VIEWS:
        layout = read(CASE / f'layouts/{view}.json')
        for clip in ('charge', 'discharge'):
            phase = definition(clip)['contact']
            rows = [r for r in records if r['view'] == view and r['clip'] == clip and r['phase'] == phase]
            if len(rows) != 1:
                errors.append(f'{view}/{clip}: missing/duplicate native exact contact')
                continue
            row = rows[0]
            full = Image.new('RGBA', (512, 512))
            for part in layout['parts']:
                name = part['name']
                expected = paints[name].crop(paints[name].getbbox())
                if name == 'column': expected = Image.fromarray(expected_glow(expected, int(channels(clip, phase).get('column.glow', 0))))
                transform = pixels.presented(bones(clip, phase, view)[name]['global'], part, layout, {})
                sampled = pixels.render(expected, transform, with_ties=True)
                info = row['layers'][name]
                actual = np.asarray(Image.open(native / info['file']).convert('RGBA'))
                if digest(native / info['file']) != info['sha256'] or actual.shape != (512, 512, 4):
                    errors.append(f'{view}/{clip}/{name}: native contact checksum/size differs')
                    continue
                match = np.array_equal(actual, sampled.default) if name == 'column' else pixels.native_frame_matches(actual, sampled.default, sampled)
                if not match: errors.append(f'{view}/{clip}/{name}: native contact pixels differ')
                full.alpha_composite(Image.fromarray(actual))
            actual = Image.open(native / row['file']).convert('RGBA')
            if digest(native / row['file']) != row['sha256'] or not np.array_equal(actual, full): errors.append(f'{view}/{clip}: native contact assembly differs')
    return errors


def pixel_gate(report, native=None):
    errors = asset_errors() + coverage(report) + motion_errors(report)
    if not bindings_match(CASE, report.get('inputs')): errors.append('Stale sample bindings')
    records, cache, previous, unique, transitions = [], {}, {}, {}, {}
    capture = read(native / 'frames.json') if native else None
    native_rows = {(r['view'], r['clip'], r['frame']): r for r in capture['frames']} if capture else {}
    if capture and (not capture.get('native_pixels') or not bindings_match(CASE, capture.get('inputs'))): errors.append('Stale/non-native capture')
    if capture:
        expected_rows = {(r['view'], r['clip'], r['frame']) for r in report['samples']}
        if set(native_rows) != expected_rows or len(native_rows) != len(capture['frames']): errors.append('Native frame coverage differs')
        errors.extend(native_contacts(capture, native))
    held_residual = 0
    paints = expected_paint()
    for row in report['samples']:
        view, clip, phase = row['view'], row['clip'], held_phase(row['clip'], row['phase'])
        key = (view, clip)
        layout = read(CASE / f'layouts/{view}.json')
        expected_bones = bones(clip, phase, view)
        level = int(channels(clip, phase).get('column.glow', 0))
        column = paints['column'].crop(paints['column'].getbbox())
        if row['glow_sha256'] != image_digest(expected_glow(column, level)): errors.append(f'{key}/{row["frame"]}: runtime glow differs')
        layers, canonical = {}, Image.new('RGBA', (512, 512))
        state_signature = []
        for part in layout['parts']:
            name = part['name']
            transform = pixels.presented(expected_bones[name]['global'], part, layout, {})
            if not np.allclose(unpack(row['parts'][name]['transform']), transform, atol=TOLERANCE, rtol=0): errors.append(f'{key}/{name}/{row["frame"]}: stepped transform differs')
            expected = paints[name].crop(paints[name].getbbox())
            image = Image.fromarray(expected_glow(expected, level)) if name == 'column' else expected
            signature = (name, level if name == 'column' else 0, tuple(transform.flatten()))
            if signature not in cache: cache[signature] = pixels.render(image, transform, with_ties=True)
            sampled = cache[signature]
            paint = sampled.default
            if capture:
                identifier = (view, clip, row['frame'])
                info = native_rows.get(identifier)
                if not info:
                    errors.append(f'{identifier}: missing native frame')
                    continue
                layer = info['layers'][name]
                path = native / layer['file']
                actual = np.asarray(Image.open(path).convert('RGBA'))
                if digest(path) != layer['sha256'] or actual.shape != (512, 512, 4):
                    errors.append(f'{identifier}/{name}: checksum/size differs')
                    continue
                # Column has no rotation: every arc, non-arc and alpha pixel is exact.
                matches = np.array_equal(actual, paint) if name == 'column' else pixels.native_frame_matches(actual, paint, sampled)
                if not matches: errors.append(f'{identifier}/{name}: native agreement/glow differs')
                ideal, _ = native_ties.select(actual, sampled)
                # The merged column's exact comparison above covers every
                # non-vent pixel too. Cap has no vent exemption at all.
                if name == 'cap': errors.extend(dark_slab_errors(actual, ideal))
                paint = actual
            canonical.alpha_composite(Image.fromarray(sampled.default))
            layers[name] = paint
            state_signature.append(signature)
        assembled = Image.new('RGBA', (512, 512))
        for part in layout['parts']:
            if part['name'] in layers: assembled.alpha_composite(Image.fromarray(layers[part['name']]))
        actual = np.asarray(assembled)
        if capture and (view, clip, row['frame']) in native_rows:
            info = native_rows[(view, clip, row['frame'])]
            full = np.asarray(Image.open(native / info['file']).convert('RGBA'))
            if digest(native / info['file']) != info['sha256'] or not np.array_equal(actual, full): errors.append(f'{key}: native assembly differs from isolated layers')
        stray = small_components(actual)
        if stray: errors.append(f'{key}/{row["frame"]}: detached components <=8px: {stray}')
        # All non-vent pixels have exact approved visible-paint provenance. Any
        # new dark slab outside the vent necessarily fails the source/native
        # agreement above; vent-only pixels are explicitly exempt, never filled.
        signature = tuple(state_signature)
        if key in previous:
            old_signature, old_image = previous[key]
            if signature == old_signature:
                residual = int(pixels.changed(old_image, actual).sum())
                held_residual += residual
                if residual: errors.append(f'{key}/{row["frame"]}: held shimmer residual {residual}')
            elif pixels.changed(old_image, actual).any(): transitions[key] = transitions.get(key, 0) + 1
        previous[key] = signature, actual
        unique.setdefault(key, set()).add(image_digest(actual))
        records.append({'view': view, 'clip': clip, 'frame': row['frame'], 'level': level, 'stray_sizes': stray})
    for (view, clip), states in unique.items():
        if clip != 'idle' and len(states) < MIN_ACTION_CHANGING_FRAMES:
            errors.append(f'{view}/{clip}: fewer than six changing presented states ({len(states)})')
    return {'ok': not errors, 'native_pixels': native is not None, 'errors': errors,
            'held_shimmer_residual': held_residual, 'dark_slab': {'vent_fill_exempt': True, 'other_pixels': 'approved painting/table provenance checked'},
            'changing_states': {'/'.join(k): len(v) for k, v in unique.items()},
            'transitions': {'/'.join(k): v for k, v in transitions.items()}, 'frames': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('headless', 'native', 'production'))
    parser.add_argument('--input', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.command == 'production':
        from rr17_production import production_errors
        report = read(args.input)
        errors = production_errors(report)
        result = {'ok': not errors, 'errors': errors}
    else:
        result = pixel_gate(read(CASE / 'proof/samples.json'), args.input if args.command == 'native' else None)
    write(args.output or CASE / ('proof/' + args.command + '_gates.json'), result)
    print('RR17 %s GATES: %s (%d errors)' % (args.command.upper(), 'PASS' if result['ok'] else 'FAIL', len(result['errors'])))
    for error in result['errors'][:12]: print(error)
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
